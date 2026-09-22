"use client";

import { useCallback, useEffect, useState } from "react";
import { SUPPORTED_BINANCE_INTERVALS, SUPPORTED_BINANCE_SYMBOLS, type BinanceInterval, type BinanceMarketSnapshot, type BinanceSymbol } from "../../lib/binance";

const money = (value: number) => new Intl.NumberFormat("en-US", { maximumFractionDigits: value >= 100 ? 2 : 6 }).format(value);
const compact = (value: number) => new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 2 }).format(value);

export default function BinancePage() {
  const [symbol, setSymbol] = useState<BinanceSymbol>("BTCUSDT");
  const [interval, setInterval] = useState<BinanceInterval>("1m");
  const [market, setMarket] = useState<BinanceMarketSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetch(`/api/v1/binance/market?symbol=${symbol}&interval=${interval}`, { cache: "no-store" });
      const body = await response.json();
      if (!response.ok) throw new Error(body.detail ?? "Unable to load live market data");
      setMarket(body as BinanceMarketSnapshot);
      setError(null);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Unable to load live market data");
    } finally {
      setLoading(false);
    }
  }, [interval, symbol]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(), 5_000);
    return () => window.clearInterval(timer);
  }, [load]);

  const changeClass = market && market.changePercent24h >= 0 ? "positive" : "negative";
  return <main className="binance-page">
    <div className="scanner-heading"><div><p className="eyebrow">LIVE CRYPTO MARKET DATA</p><h1>Binance Spot</h1><p className="lead">Datos públicos reales, actualizados cada cinco segundos. Este panel analiza mercado: no tiene permisos para ejecutar órdenes.</p></div><p className="live-badge"><span /> LIVE / PUBLIC API</p></div>
    <section className="binance-controls" aria-label="Live market controls"><div><p className="detail-label">Market</p><div className="market-tabs">{SUPPORTED_BINANCE_SYMBOLS.map((item) => <button className={`market-tab ${item === symbol ? "selected" : ""}`} onClick={() => setSymbol(item)} type="button" key={item}>{item.replace("USDT", "/USDT")}</button>)}</div></div><div><p className="detail-label">Candle interval</p><div className="timeframe-tabs">{SUPPORTED_BINANCE_INTERVALS.map((item) => <button className={`timeframe-tab ${item === interval ? "selected" : ""}`} onClick={() => setInterval(item)} type="button" key={item}>{item}</button>)}</div></div></section>
    {error ? <section className="connection-error"><strong>Connection status</strong><p>{error}</p><button type="button" onClick={() => void load()}>Retry live data</button></section> : null}
    <section className="binance-summary" aria-live="polite"><article className="price-card"><p className="detail-label">{symbol}</p><strong>{market ? `$${money(market.price)}` : "—"}</strong><span className={changeClass}>{market ? `${market.changePercent24h >= 0 ? "+" : ""}${market.changePercent24h.toFixed(2)}% / 24h` : "Loading live price…"}</span></article><article><p className="detail-label">24h range</p><strong>{market ? `$${money(market.low24h)} — $${money(market.high24h)}` : "—"}</strong><p>High and low from Binance Spot.</p></article><article><p className="detail-label">24h volume</p><strong>{market ? `$${compact(market.quoteVolume24h)}` : "—"}</strong><p>Quote volume in USDT.</p></article><article><p className="detail-label">Order book spread</p><strong>{market ? `$${money(market.orderBook.spread)}` : "—"}</strong><p>{market ? `Bid pressure ${(market.orderBook.imbalance * 100).toFixed(0)}%` : "Loading…"}</p></article></section>
    <section className="binance-workspace"><article className="candle-panel"><div className="panel-heading"><div><p className="detail-label">Last closed candles</p><h2>{symbol.replace("USDT", "/USDT")} · {interval}</h2></div><span>{loading ? "Refreshing" : market ? new Date(market.asOf).toLocaleTimeString() : "—"}</span></div><CandleBars candles={market?.candles ?? []} /></article><article className="orderbook-panel"><p className="detail-label">Best prices</p><dl><div><dt>Bid</dt><dd>{market ? `$${money(market.orderBook.bid)}` : "—"}</dd></div><div><dt>Ask</dt><dd>{market ? `$${money(market.orderBook.ask)}` : "—"}</dd></div><div><dt>Imbalance</dt><dd>{market ? `${(market.orderBook.imbalance * 100).toFixed(1)}% bid` : "—"}</dd></div></dl><p className="panel-note">La presión del libro no es una señal de compra o venta. Úsala junto con la estrategia validada.</p></article></section>
    <p className="disclaimer">Datos de Binance Spot para análisis. Los activos digitales son volátiles; no hay garantías de rendimiento ni ejecución automática desde este panel.</p>
  </main>;
}

function CandleBars({ candles }: { candles: BinanceMarketSnapshot["candles"] }) {
  if (!candles.length) return <p className="chart-empty">Loading closed candles…</p>;
  const visible = candles.slice(-48);
  const low = Math.min(...visible.map((candle) => candle.low));
  const high = Math.max(...visible.map((candle) => candle.high));
  const range = Math.max(high - low, Number.EPSILON);
  return <div className="candle-chart" aria-label="Recent closed candle chart">{visible.map((candle) => {
    const isUp = candle.close >= candle.open;
    const highOffset = ((high - candle.high) / range) * 100;
    const wickHeight = ((candle.high - candle.low) / range) * 100;
    const bodyTop = ((high - Math.max(candle.open, candle.close)) / range) * 100;
    const bodyHeight = Math.max(((Math.abs(candle.close - candle.open)) / range) * 100, 1.2);
    return <div className="candle" title={`${new Date(candle.time).toLocaleTimeString()} O ${candle.open} H ${candle.high} L ${candle.low} C ${candle.close}`} key={candle.time}><i className={isUp ? "wick up" : "wick down"} style={{ top: `${highOffset}%`, height: `${wickHeight}%` }} /><b className={isUp ? "up" : "down"} style={{ top: `${bodyTop}%`, height: `${bodyHeight}%` }} /></div>;
  })}</div>;
}
