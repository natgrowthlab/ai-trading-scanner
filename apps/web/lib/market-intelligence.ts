/**
 * Node-compatible market intelligence adapter.
 *
 * Hostinger Web Apps runs Node.js only, so this adapter exposes the same
 * read-only API contract as the FastAPI intelligence service.  It intentionally
 * uses deterministic MOCK candles until a licensed market-data provider is
 * connected; all responses state that fact explicitly.
 */
export const SUPPORTED_MARKETS = ["NQ", "ES", "YM", "RTY", "GC"] as const;
export const SUPPORTED_TIMEFRAMES = ["1m", "3m", "5m", "15m", "30m", "1h", "4h", "1D", "1W"] as const;
type Market = typeof SUPPORTED_MARKETS[number];
type Timeframe = typeof SUPPORTED_TIMEFRAMES[number];
type Candle = { timestamp: string; open: number; high: number; low: number; close: number };

const instruments: Record<Market, { base: number; tickSize: number; tickValue: number; maxContracts: number }> = {
  NQ: { base: 22000, tickSize: .25, tickValue: 5, maxContracts: 10 },
  ES: { base: 6100, tickSize: .25, tickValue: 12.5, maxContracts: 10 },
  YM: { base: 43000, tickSize: 1, tickValue: 5, maxContracts: 10 },
  RTY: { base: 2250, tickSize: .1, tickValue: 5, maxContracts: 10 },
  GC: { base: 4400, tickSize: .1, tickValue: 10, maxContracts: 10 },
};

const minutes: Record<Timeframe, number> = { "1m": 1, "3m": 3, "5m": 5, "15m": 15, "30m": 30, "1h": 60, "4h": 240, "1D": 1440, "1W": 10080 };

function assertInput(symbol: string, timeframe: string): asserts symbol is Market {
  if (!SUPPORTED_MARKETS.includes(symbol as Market)) throw new Error("Unsupported market");
  if (!SUPPORTED_TIMEFRAMES.includes(timeframe as Timeframe)) throw new Error("Unsupported timeframe");
}

function candles(symbol: Market, timeframe: Timeframe, count = 120): Candle[] {
  const interval = minutes[timeframe] * 60_000;
  const start = Date.UTC(2025, 0, 1);
  const { base, tickSize } = instruments[symbol];
  return Array.from({ length: count }, (_, index) => {
    const trend = index * tickSize * 2;
    const wave = Math.sin(index / 5) * tickSize * 6;
    const open = base + trend + wave;
    const close = open + (index % 7 < 4 ? tickSize * 3 : -tickSize * 2);
    return { timestamp: new Date(start + index * interval).toISOString(), open, close, high: Math.max(open, close) + tickSize * 2, low: Math.min(open, close) - tickSize * 2 };
  });
}

function session(ts: string) {
  const hour = new Date(ts).getUTCHours(); // deterministic mock uses UTC; production is exchange-time aware in FastAPI.
  if (hour >= 14 && hour < 16) return "NY_AM";
  if (hour >= 16 && hour < 18) return "LUNCH";
  if (hour >= 18 && hour < 20) return "NY_PM";
  return hour >= 9 && hour < 14 ? "PREMARKET" : "AFTER_HOURS";
}

function swings(items: Candle[]) {
  return items.slice(3, -3).flatMap((c, offset) => {
    const index = offset + 3;
    const window = items.slice(index - 3, index + 4);
    const high = Math.max(...window.map(x => x.high));
    const low = Math.min(...window.map(x => x.low));
    const output: object[] = [];
    if (c.high === high) output.push({ type: "HIGH", price: c.high, timestamp: c.timestamp, confirmedAt: items[index + 3].timestamp });
    if (c.low === low) output.push({ type: "LOW", price: c.low, timestamp: c.timestamp, confirmedAt: items[index + 3].timestamp });
    return output;
  }) as Array<{ type: "HIGH" | "LOW"; price: number; timestamp: string; confirmedAt: string }>;
}

function risk(symbol: Market, entry: number, stop: number) {
  const i = instruments[symbol];
  const riskUSD = 100;
  const perContract = Math.abs(entry - stop) / i.tickSize * i.tickValue;
  const contracts = perContract ? Math.min(i.maxContracts, Math.floor(riskUSD / perContract)) : 0;
  return { riskUSD, stopDistance: Number(Math.abs(entry - stop).toFixed(4)), contracts, maxLoss: Number((contracts * perContract).toFixed(2)) };
}

export function analyzeMarket(symbolInput: string, timeframeInput = "5m") {
  assertInput(symbolInput, timeframeInput);
  const symbol = symbolInput as Market;
  const timeframe = timeframeInput as Timeframe;
  const items = candles(symbol, timeframe);
  const last = items.at(-1)!;
  const sessionLevels = [
    { type: "ASIA_HIGH", price: Math.max(...items.slice(0, 48).map(x => x.high)), timestamp: items[47].timestamp, state: "UNTOUCHED" },
    { type: "ASIA_LOW", price: Math.min(...items.slice(0, 48).map(x => x.low)), timestamp: items[47].timestamp, state: "UNTOUCHED" },
    { type: "PDH", price: Math.max(...items.slice(-48, -24).map(x => x.high)), timestamp: items.at(-25)!.timestamp, state: "UNTOUCHED" },
    { type: "PDL", price: Math.min(...items.slice(-48, -24).map(x => x.low)), timestamp: items.at(-25)!.timestamp, state: "UNTOUCHED" },
  ];
  const pivots = swings(items).slice(-20);
  const highs = pivots.filter(x => x.type === "HIGH");
  const lows = pivots.filter(x => x.type === "LOW");
  const trend = highs.length > 1 && lows.length > 1 && highs.at(-1)!.price > highs.at(-2)!.price && lows.at(-1)!.price > lows.at(-2)!.price ? "BULLISH" : "NEUTRAL";
  const fvg = items.slice(2).flatMap((third, offset) => {
    const first = items[offset];
    if (first.high < third.low) return [{ direction: "BULLISH", upperPrice: third.low, lowerPrice: first.high, createdAt: third.timestamp, mitigated: false }];
    if (first.low > third.high) return [{ direction: "BEARISH", upperPrice: first.low, lowerPrice: third.high, createdAt: third.timestamp, mitigated: false }];
    return [];
  }).slice(-20);
  const liquidity = [...sessionLevels.map((x, index) => ({ ...x, id: `${x.type}-${x.timestamp}`, importanceScore: x.type.startsWith("PD") ? 80 : 60, touches: 0, swept: false })), ...pivots.map(x => ({ id: `SWING_${x.type}-${x.timestamp}`, type: `SWING_${x.type}`, price: x.price, timestamp: x.timestamp, state: "UNTOUCHED", importanceScore: 50, touches: 0, swept: false }))];
  const direction = last.close > last.open || trend === "BULLISH" ? "BULLISH" : "BEARISH";
  const displacement = Math.min(100, Math.round(Math.abs(last.close - last.open) / Math.max(last.high - last.low, .0001) * 100));
  const confirmations = { dailyBias: 15, liquiditySweep: 0, structure: trend === "BULLISH" ? 15 : 0, displacement: displacement >= 50 ? 10 : 0, fvg: fvg.some(x => x.direction === direction) ? 10 : 0, session: ["NY_AM", "NY_PM"].includes(session(last.timestamp)) ? 10 : 3, riskReward: 5 };
  const confidence = Object.values(confirmations).reduce((total, value) => total + value, 0);
  const stop = direction === "BULLISH" ? last.low : last.high;
  const setup = confidence >= 65 && trend === "BULLISH" ? { id: `${symbol}-${last.timestamp}`, direction: direction === "BULLISH" ? "LONG" : "SHORT", status: "CONFIRMED", preferredEntry: last.close, entryZone: { low: last.close, high: last.close }, stopLoss: stop, targets: [1, 2, 3].map(multiplier => last.close + (direction === "BULLISH" ? 1 : -1) * Math.abs(last.close - stop) * multiplier), riskReward: 3, confidence, confirmations, risk: risk(symbol, last.close, stop) } : null;
  return { symbol, timeframe, dataStatus: "MOCK", currentPrice: last.close, session: session(last.timestamp), levels: sessionLevels, liquidity, structure: { trend, swings: pivots, events: [] }, sweeps: [], fvg, smt: { status: "UNAVAILABLE", reason: "Comparison candles not supplied" }, displacement: { score: displacement }, bias: { direction, score: direction === "BULLISH" ? 70 : 30, reasons: ["deterministic mock candles", "latest candle direction"] }, confidence: { score: confidence, components: confirmations }, setup };
}

export function listScanner(timeframe = "5m") { return SUPPORTED_MARKETS.map(symbol => analyzeMarket(symbol, timeframe)); }

export function evaluatePropAccount(input: { accountSize: number; currentBalance: number; maxDailyLoss: number; maxTotalLoss: number; dailyLoss: number; totalDrawdown: number }) {
  const dailyLossRemaining = Math.max(0, input.maxDailyLoss - input.dailyLoss);
  const drawdownRemaining = Math.max(0, input.maxTotalLoss - input.totalDrawdown);
  const consumed = Math.max(1 - dailyLossRemaining / input.maxDailyLoss, 1 - drawdownRemaining / input.maxTotalLoss);
  const riskMultiplier = consumed < .25 ? 1 : consumed < .5 ? .75 : consumed < .75 ? .5 : .25;
  return { currentEquity: input.currentBalance, dailyLossRemaining, drawdownRemaining, riskMultiplier, maximumSafeRisk: Number((input.accountSize * .01 * riskMultiplier).toFixed(2)), status: Math.min(dailyLossRemaining, drawdownRemaining) <= 0 ? "LOCKED" : consumed >= .75 ? "DANGER" : consumed >= .5 ? "CAUTION" : "SAFE" };
}
