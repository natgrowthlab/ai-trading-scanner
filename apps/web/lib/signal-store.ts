import mysql, { Pool, RowDataPacket } from "mysql2/promise";
import type { TradingViewSignal } from "./tradingview-signals";

const fallbackSignals: TradingViewSignal[] = [];
let pool: Pool | null | undefined;
let schemaReady: Promise<void> | undefined;

function databasePool(): Pool | null {
  if (pool !== undefined) return pool;
  const { DATABASE_HOST, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD } = process.env;
  if (!DATABASE_HOST || !DATABASE_NAME || !DATABASE_USER || !DATABASE_PASSWORD) return pool = null;
  return pool = mysql.createPool({ host: DATABASE_HOST, port: Number(process.env.DATABASE_PORT ?? 3306), database: DATABASE_NAME, user: DATABASE_USER, password: DATABASE_PASSWORD, waitForConnections: true, connectionLimit: 5, enableKeepAlive: true });
}

async function ensureSchema(current: Pool) {
  schemaReady ??= current.query(`CREATE TABLE IF NOT EXISTS tradingview_signals (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    symbol VARCHAR(32) NOT NULL, direction ENUM('LONG','SHORT') NOT NULL, score INT NOT NULL,
    entry DECIMAL(18,6) NOT NULL, stop_loss DECIMAL(18,6) NOT NULL,
    tp1 DECIMAL(18,6) NOT NULL, tp2 DECIMAL(18,6) NOT NULL, tp3 DECIMAL(18,6) NOT NULL,
    risk_usd DECIMAL(12,2) NOT NULL, status VARCHAR(24) NOT NULL, timeframe VARCHAR(8) NOT NULL,
    received_at DATETIME(3) NOT NULL, INDEX received_at_index (received_at)
  ) ENGINE=InnoDB`).then(() => undefined);
  await schemaReady;
}

export async function persistSignal(signal: TradingViewSignal): Promise<TradingViewSignal> {
  const current = databasePool();
  if (!current) { fallbackSignals.unshift(signal); fallbackSignals.splice(100); return signal; }
  try {
    await ensureSchema(current);
    const [result] = await current.execute<mysql.ResultSetHeader>("INSERT INTO tradingview_signals (symbol, direction, score, entry, stop_loss, tp1, tp2, tp3, risk_usd, status, timeframe, received_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [signal.symbol, signal.direction, signal.score, signal.entry, signal.stopLoss, signal.tp1, signal.tp2, signal.tp3, signal.riskUsd, signal.status, signal.timeframe, signal.receivedAt]);
    return { ...signal, id: Number(result.insertId) };
  } catch { throw new Error("storage"); }
}

export async function listStoredSignals(): Promise<TradingViewSignal[]> {
  const current = databasePool();
  if (!current) return fallbackSignals;
  try {
    await ensureSchema(current);
    const [rows] = await current.query<Array<RowDataPacket & { id: number; symbol: string; direction: "LONG" | "SHORT"; score: number; entry: string; stop_loss: string; tp1: string; tp2: string; tp3: string; risk_usd: string; status: "received"; timeframe: string; received_at: Date }>>("SELECT id, symbol, direction, score, entry, stop_loss, tp1, tp2, tp3, risk_usd, status, timeframe, received_at FROM tradingview_signals ORDER BY received_at DESC LIMIT 100");
    return rows.map(row => ({ id: Number(row.id), symbol: row.symbol, direction: row.direction, score: Number(row.score), tier: "BASE", reasons: [], entry: String(row.entry), stopLoss: String(row.stop_loss), tp1: String(row.tp1), tp2: String(row.tp2), tp3: String(row.tp3), riskUsd: Number(row.risk_usd), status: row.status, timeframe: row.timeframe, receivedAt: new Date(row.received_at).toISOString() }));
  } catch { throw new Error("storage"); }
}

export async function storageHealth(): Promise<{ storage: "MYSQL_CONNECTED" | "MYSQL_UNAVAILABLE" | "EPHEMERAL_RUNTIME"; signalCount: number }> {
  const current = databasePool();
  if (!current) return { storage: "EPHEMERAL_RUNTIME", signalCount: fallbackSignals.length };
  try {
    await ensureSchema(current);
    const [rows] = await current.query<Array<RowDataPacket & { total: number }>>("SELECT COUNT(*) AS total FROM tradingview_signals");
    return { storage: "MYSQL_CONNECTED", signalCount: Number(rows[0]?.total ?? 0) };
  } catch { return { storage: "MYSQL_UNAVAILABLE", signalCount: 0 }; }
}
