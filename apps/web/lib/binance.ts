export const SUPPORTED_BINANCE_SYMBOLS = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "BNBUSDT", "XRPUSDT"] as const;
export const SUPPORTED_BINANCE_INTERVALS = ["1m", "5m", "15m", "1h"] as const;

export type BinanceSymbol = typeof SUPPORTED_BINANCE_SYMBOLS[number];
export type BinanceInterval = typeof SUPPORTED_BINANCE_INTERVALS[number];

type Kline = [number, string, string, string, string, string, number, string, number, string, string, string];
type Ticker = {
  lastPrice: string;
  priceChangePercent: string;
  highPrice: string;
  lowPrice: string;
  quoteVolume: string;
};
type Depth = { bids: [string, string][]; asks: [string, string][] };

export type BinanceMarketSnapshot = {
  provider: "BINANCE_USDTM_FUTURES";
  symbol: BinanceSymbol;
  interval: BinanceInterval;
  asOf: string;
  price: number;
  changePercent24h: number;
  high24h: number;
  low24h: number;
  quoteVolume24h: number;
  orderBook: { bid: number; ask: number; spread: number; imbalance: number };
  candles: { time: number; open: number; high: number; low: number; close: number; volume: number }[];
};

const DEFAULT_BINANCE_ENDPOINTS = [
  "https://fapi.binance.com",
  "https://demo-fapi.binance.com",
  "https://testnet.binancefuture.com",
];

export function parseSymbol(value: string | null): BinanceSymbol {
  if (value && SUPPORTED_BINANCE_SYMBOLS.includes(value as BinanceSymbol)) return value as BinanceSymbol;
  return "BTCUSDT";
}

export function parseInterval(value: string | null): BinanceInterval {
  if (value && SUPPORTED_BINANCE_INTERVALS.includes(value as BinanceInterval)) return value as BinanceInterval;
  return "1m";
}

export async function loadBinanceMarket(symbol: BinanceSymbol, interval: BinanceInterval): Promise<BinanceMarketSnapshot> {
  const configuredEndpoint = process.env.BINANCE_PUBLIC_API_BASE_URL?.replace(/\/$/, "");
  const endpoints = configuredEndpoint ? [configuredEndpoint, ...DEFAULT_BINANCE_ENDPOINTS.filter((endpoint) => endpoint !== configuredEndpoint)] : DEFAULT_BINANCE_ENDPOINTS;
  for (const endpoint of endpoints) {
    try {
      return await loadFromEndpoint(endpoint, symbol, interval);
    } catch {
      // Public exchange endpoints can be regionally unavailable from a serverless region.
      // A fallback still provides real Spot market data without client-side credentials.
    }
  }
  throw new Error("Binance market data is temporarily unavailable");
}

async function loadFromEndpoint(endpoint: string, symbol: BinanceSymbol, interval: BinanceInterval): Promise<BinanceMarketSnapshot> {
  const query = new URLSearchParams({ symbol });
  const [tickerResponse, depthResponse, klinesResponse] = await Promise.all([
    fetch(`${endpoint}/fapi/v1/ticker/24hr?${query}`, { next: { revalidate: 5 } }),
    fetch(`${endpoint}/fapi/v1/depth?${new URLSearchParams({ symbol, limit: "5" })}`, { next: { revalidate: 5 } }),
    fetch(`${endpoint}/fapi/v1/klines?${new URLSearchParams({ symbol, interval, limit: "80" })}`, { next: { revalidate: 5 } }),
  ]);
  if (!tickerResponse.ok || !depthResponse.ok || !klinesResponse.ok) {
    throw new Error("Binance market data is temporarily unavailable");
  }
  const ticker = await tickerResponse.json() as Ticker;
  const depth = await depthResponse.json() as Depth;
  const klines = await klinesResponse.json() as Kline[];
  const bestBid = Number(depth.bids[0]?.[0]);
  const bestAsk = Number(depth.asks[0]?.[0]);
  if (!Number.isFinite(bestBid) || !Number.isFinite(bestAsk) || !klines.length) {
    throw new Error("Binance returned incomplete market data");
  }
  const bidQuantity = depth.bids.reduce((total, [, quantity]) => total + Number(quantity), 0);
  const askQuantity = depth.asks.reduce((total, [, quantity]) => total + Number(quantity), 0);
  return {
    provider: "BINANCE_USDTM_FUTURES",
    symbol,
    interval,
    asOf: new Date().toISOString(),
    price: Number(ticker.lastPrice),
    changePercent24h: Number(ticker.priceChangePercent),
    high24h: Number(ticker.highPrice),
    low24h: Number(ticker.lowPrice),
    quoteVolume24h: Number(ticker.quoteVolume),
    orderBook: {
      bid: bestBid,
      ask: bestAsk,
      spread: bestAsk - bestBid,
      imbalance: bidQuantity + askQuantity ? bidQuantity / (bidQuantity + askQuantity) : 0.5,
    },
    candles: klines.slice(0, -1).map((row) => ({
      time: row[0], open: Number(row[1]), high: Number(row[2]), low: Number(row[3]), close: Number(row[4]), volume: Number(row[5]),
    })),
  };
}
