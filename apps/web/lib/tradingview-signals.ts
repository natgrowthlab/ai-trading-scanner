import { timingSafeEqual } from "node:crypto";
import { listStoredSignals, persistSignal } from "./signal-store";

export type TradingViewSignal = {
  id: number;
  symbol: string;
  direction: "LONG" | "SHORT";
  score: number;
  entry: string;
  stopLoss: string;
  tp1: string;
  tp2: string;
  tp3: string;
  riskUsd: number;
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
  stop_loss?: unknown;
};

const supportedTimeframes: Record<string, string> = {
  "1": "1m", "3": "3m", "5": "5m", "15": "15m", "30": "30m", "60": "1h", "240": "4h", D: "1D",
  "1m": "1m", "3m": "3m", "5m": "5m", "15m": "15m", "30m": "30m", "1h": "1h", "4h": "4h", "1D": "1D",
};

const recentKeys = new Map<string, number>();
let nextId = 1;
const DEDUPLICATION_WINDOW_MS = 60_000;

function isExpectedSecret(supplied: string): boolean {
  const expected = process.env.TRADINGVIEW_WEBHOOK_SECRET;
  if (!expected) return false;
  const left = Buffer.from(supplied);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

async function notifyTelegram(signal: TradingViewSignal): Promise<void> {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) return;

  const text = [
    "📈 AI Trading Scanner",
    `${signal.direction === "LONG" ? "BUY" : "SELL"} ${signal.symbol}`,
    `Entry: ${signal.entry}`,
    `SL: ${signal.stopLoss}`,
    `TP1: ${signal.tp1}`,
    `TP2: ${signal.tp2}`,
    `TP3: ${signal.tp3}`,
    `Risk: $${signal.riskUsd.toFixed(2)} (1% of $10,000)`,
    `Timeframe: ${signal.timeframe}`,
  ].join("\n");

  try {
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text, disable_web_page_preview: true }),
      signal: AbortSignal.timeout(5_000),
    });
  } catch {
    // Telegram delivery must not cause a valid webhook ingestion to fail.
  }
}

export async function ingestTradingViewPayload(payload: TradingViewPayload): Promise<{ status: "accepted" | "duplicate" }> {
  if (typeof payload.secret !== "string" || !isExpectedSecret(payload.secret)) throw new Error("unauthorized");
  if (payload.event !== "SIGNAL" || typeof payload.symbol !== "string" || !/^[A-Z0-9:!_-]{3,32}$/i.test(payload.symbol)) throw new Error("invalid");
  if (payload.direction !== "LONG" && payload.direction !== "SHORT") throw new Error("invalid");
  if (typeof payload.timeframe !== "string" || !supportedTimeframes[payload.timeframe]) throw new Error("invalid");
  const price = Number(payload.price);
  if (!Number.isFinite(price) || price <= 0 || price > 10_000_000) throw new Error("invalid");

  const proposedStop = Number(payload.stop_loss);
  const fallbackStop = payload.direction === "LONG" ? price * 0.99 : price * 1.01;
  const stop = Number.isFinite(proposedStop) && proposedStop > 0 && (
    (payload.direction === "LONG" && proposedStop < price) ||
    (payload.direction === "SHORT" && proposedStop > price)
  ) ? proposedStop : fallbackStop;
  const riskDistance = Math.abs(price - stop);
  const target = (multiple: number) => payload.direction === "LONG"
    ? price + riskDistance * multiple
    : price - riskDistance * multiple;
  const format = (value: number) => value.toFixed(2);

  const timeframe = supportedTimeframes[payload.timeframe];
  const key = `${payload.symbol}|${timeframe}|${payload.direction}`;
  const now = Date.now();
  for (const [recentKey, receivedAt] of recentKeys) if (now - receivedAt >= DEDUPLICATION_WINDOW_MS) recentKeys.delete(recentKey);
  if (now - (recentKeys.get(key) ?? 0) < DEDUPLICATION_WINDOW_MS) return { status: "duplicate" };
  recentKeys.set(key, now);
  const signal: TradingViewSignal = {
    id: nextId++, symbol: payload.symbol, direction: payload.direction, score: 0,
    entry: format(price), stopLoss: format(stop), tp1: format(target(1)), tp2: format(target(2)), tp3: format(target(3)), riskUsd: 100,
    status: "received", timeframe, receivedAt: new Date(now).toISOString(),
  };
  const storedSignal = await persistSignal(signal);
  await notifyTelegram(storedSignal);
  return { status: "accepted" };
}

export async function listTradingViewSignals(): Promise<TradingViewSignal[]> {
  return listStoredSignals();
}
