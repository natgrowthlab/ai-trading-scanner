import mysql, { Pool, RowDataPacket } from "mysql2/promise";
import type { Btc5mReadiness, Btc5mReadinessInput } from "./polymarket-readiness";

export type StoredReadinessReview = Btc5mReadinessInput & {
  id: number;
  decision: Btc5mReadiness["decision"];
  reviewedAt: string;
};

let pool: Pool | null | undefined;
let schemaReady: Promise<void> | undefined;
const fallbackReviews: StoredReadinessReview[] = [];

function databasePool(): Pool | null {
  if (pool !== undefined) return pool;
  const { DATABASE_HOST, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD } = process.env;
  if (!DATABASE_HOST || !DATABASE_NAME || !DATABASE_USER || !DATABASE_PASSWORD) return pool = null;
  return pool = mysql.createPool({ host: DATABASE_HOST, port: Number(process.env.DATABASE_PORT ?? 3306), database: DATABASE_NAME, user: DATABASE_USER, password: DATABASE_PASSWORD, waitForConnections: true, connectionLimit: 5, enableKeepAlive: true });
}

async function ensureSchema(current: Pool) {
  schemaReady ??= current.query(`CREATE TABLE IF NOT EXISTS polymarket_readiness_reviews (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    market_active BOOLEAN NOT NULL, seconds_remaining SMALLINT UNSIGNED NOT NULL,
    btc_move_usd DECIMAL(12,2) NOT NULL, selected_side_price DECIMAL(6,5) NOT NULL,
    decision ENUM('READY_FOR_REVIEW','NOT_READY') NOT NULL,
    reviewed_at DATETIME(3) NOT NULL, INDEX reviewed_at_index (reviewed_at)
  ) ENGINE=InnoDB`).then(() => undefined);
  await schemaReady;
}

export async function persistReadinessReview(input: Btc5mReadinessInput, result: Btc5mReadiness): Promise<StoredReadinessReview> {
  const review: StoredReadinessReview = { ...input, id: 0, decision: result.decision, reviewedAt: new Date().toISOString() };
  const current = databasePool();
  if (!current) { review.id = -(fallbackReviews.length + 1); fallbackReviews.unshift(review); fallbackReviews.splice(100); return review; }
  await ensureSchema(current);
  const [insert] = await current.execute<mysql.ResultSetHeader>("INSERT INTO polymarket_readiness_reviews (market_active, seconds_remaining, btc_move_usd, selected_side_price, decision, reviewed_at) VALUES (?, ?, ?, ?, ?, ?)", [review.marketActive, review.secondsRemaining, review.btcMoveUsd, review.selectedSidePrice, review.decision, review.reviewedAt]);
  return { ...review, id: Number(insert.insertId) };
}

export async function listReadinessReviews(): Promise<StoredReadinessReview[]> {
  const current = databasePool();
  if (!current) return fallbackReviews;
  await ensureSchema(current);
  const [rows] = await current.query<Array<RowDataPacket & { id: number; market_active: number; seconds_remaining: number; btc_move_usd: string; selected_side_price: string; decision: StoredReadinessReview["decision"]; reviewed_at: Date }>>("SELECT id, market_active, seconds_remaining, btc_move_usd, selected_side_price, decision, reviewed_at FROM polymarket_readiness_reviews ORDER BY reviewed_at DESC LIMIT 25");
  return rows.map((row) => ({ id: Number(row.id), marketActive: Boolean(row.market_active), secondsRemaining: Number(row.seconds_remaining), btcMoveUsd: Number(row.btc_move_usd), selectedSidePrice: Number(row.selected_side_price), decision: row.decision, reviewedAt: new Date(row.reviewed_at).toISOString() }));
}
