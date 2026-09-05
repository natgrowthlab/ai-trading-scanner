import { timingSafeEqual } from "node:crypto";

export type TradingViewSignal = {
  id: number;
  symbol: string;
  direction: "LONG" | "SHORT";
  score: number;
  entry: string;
  status: "received";
  timeframe: string;
  receivedAt: string;
};

type TradingViewPayload = {
  secret?: unknown;
  symbol?: unknown;
  timeframe?: unknown;
  event?: unknown;
  direction?: unknown;
  price?: unknown;
};

const supportedTimeframes: Record<string, string> = {
  "1": "1m", "3": "3m", "5": "5m", "15": "15m", "30": "30m", "60": "1h", "240": "4h", D: "1D",
  "1m": "1m", "3m": "3m", "5m": "5m", "15m": "15m", "30m": "30m", "1h": "1h", "4h": "4h", "1D": "1D",
};

const recentSignals: TradingViewSignal[] = [];
const recentKeys = new Map<string, number>();
let nextId = 1;

function isExpectedSecret(supplied: string): boolean {
  const expected = process.env.TRADINGVIEW_WEBHOOK_SECRET;
  if (!expected) return false;
  const left = Buffer.from(supplied);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

export function ingestTradingViewPayload(payload: TradingViewPayload): { status: "accepted" | "duplicate" } {
  if (typeof payload.secret !== "string" || !isExpectedSecret(payload.secret)) throw new Error("unauthorized");
  if (payload.event !== "SIGNAL" || typeof payload.symbol !== "string" || !/^[A-Z0-9:_-]{3,32}$/i.test(payload.symbol)) throw new Error("invalid");
  if (payload.direction !== "LONG" && payload.direction !== "SHORT") throw new Error("invalid");
  if (typeof payload.timeframe !== "string" || !supportedTimeframes[payload.timeframe]) throw new Error("invalid");
  const price = Number(payload.price);
  if (!Number.isFinite(price) || price <= 0) throw new Error("invalid");

  const timeframe = supportedTimeframes[payload.timeframe];
  const key = `${payload.symbol}|${timeframe}|${payload.direction}`;
  const now = Date.now();
  if (now - (recentKeys.get(key) ?? 0) < 60_000) return { status: "duplicate" };
  recentKeys.set(key, now);
  recentSignals.unshift({ id: nextId++, symbol: payload.symbol, direction: payload.direction, score: 0, entry: price.toString(), status: "received", timeframe, receivedAt: new Date(now).toISOString() });
  recentSignals.splice(100);
  return { status: "accepted" };
}

export function listTradingViewSignals(): TradingViewSignal[] {
  return recentSignals;
}
