"use client";

import { useEffect, useMemo, useState } from "react";

type Level = { type: string; price: number; state: string };
type Gap = { direction: string; lowerPrice: number; upperPrice: number; mitigated: boolean };
type Scan = { symbol: string; dataStatus: string; currentPrice: number; session: string; bias: { direction: string; score: number }; confidence: { score: number }; levels: Level[]; fvg: Gap[]; setup: { direction: string; riskReward: number; preferredEntry: number; stopLoss: number; targets: number[]; risk: { riskUSD: number; contracts: number } } | null };
const timeframes = ["1m", "5m", "1h", "1D"] as const;
type Timeframe = typeof timeframes[number];

function price(value: number) { return new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(value); }

export default function ScannerPage() {
  const [rows, setRows] = useState<Scan[] | null>(null);
  const [error, setError] = useState(false);
  const [selectedSymbol, setSelectedSymbol] = useState("BTCUSDT");
  const [timeframe, setTimeframe] = useState<Timeframe>("5m");
  useEffect(() => { let active = true; const base = process.env.NEXT_PUBLIC_API_BASE_URL ?? "/api/v1"; setRows(null); fetch(`${base}/scanner?timeframe=${timeframe}`).then(r => r.ok ? r.json() : Promise.reject(r)).then(nextRows => { if (active) { setRows(nextRows); setError(false); } }).catch(() => active && setError(true)); return () => { active = false; }; }, [timeframe]);
  const selected = useMemo(() => rows?.find(row => row.symbol === selectedSymbol) ?? rows?.[0] ?? null, [rows, selectedSymbol]);
  return <main className="scanner-page">
    <div className="scanner-heading"><div><p className="eyebrow">BINANCE FUTURES RESEARCH</p><h1>Crypto futures scanner</h1><p className="lead">Confluence analysis for USDT‑M perpetual contracts. Select a crypto market to inspect its structure.</p></div><div className="data-badge" aria-label="Current data status">SIMULATION · NO LIVE EXECUTION</div></div>
    {error ? <p className="empty">Scanner API unavailable. Check the active Web App deployment.</p> : rows === null ? <p className="empty">Loading scanner…</p> : <>
      <div className="scanner-controls"><div className="timeframe-tabs" role="tablist" aria-label="Analysis timeframe">{timeframes.map(item => <button key={item} role="tab" aria-selected={timeframe === item} className={timeframe === item ? "timeframe-tab selected" : "timeframe-tab"} onClick={() => setTimeframe(item)}>{item}</button>)}</div><div className="market-tabs" role="tablist" aria-label="Markets">{rows.map(row => <button key={row.symbol} role="tab" aria-selected={selected?.symbol === row.symbol} className={selected?.symbol === row.symbol ? "market-tab selected" : "market-tab"} onClick={() => setSelectedSymbol(row.symbol)}>{row.symbol}<span>{row.bias.direction}</span></button>)}</div></div>
      <div className="table-wrap"><table><caption className="sr-only">Market intelligence scanner. Select a row to inspect details.</caption><thead><tr><th>Market</th><th>Price</th><th>Bias</th><th>Confidence</th><th>Setup</th><th>Data</th></tr></thead><tbody>{rows.map(row => <tr key={row.symbol} className={selected?.symbol === row.symbol ? "active-row" : undefined} onClick={() => setSelectedSymbol(row.symbol)}><td><button className="row-button" aria-label={`Inspect ${row.symbol}`}>{row.symbol}</button></td><td>{price(row.currentPrice)}</td><td><span className={row.bias.direction === "BULLISH" ? "signal positive" : "signal negative"}>{row.bias.direction} · {row.bias.score}</span></td><td>{row.confidence.score}/85</td><td>{row.setup ? `${row.setup.direction} · ${row.setup.riskReward}R` : "No confirmed setup"}</td><td>{row.dataStatus}</td></tr>)}</tbody></table></div>
      {selected && <section className="market-detail" aria-label={`${selected.symbol} intelligence details`}><article className="detail-overview"><p className="detail-label">Selected market</p><h2>{selected.symbol} <span>{price(selected.currentPrice)}</span></h2><p className="detail-meta">{timeframe} · {selected.session} · <strong>{selected.dataStatus}</strong></p><div className="score-grid"><div><span>Bias</span><strong>{selected.bias.score}</strong><small>{selected.bias.direction}</small></div><div><span>Confluence</span><strong>{selected.confidence.score}</strong><small>needs 65 to validate</small></div><div><span>FVGs</span><strong>{selected.fvg.length}</strong><small>latest 20 zones</small></div></div></article>
        <article><p className="detail-label">Key liquidity</p><ul className="level-list">{selected.levels.slice(-4).map(level => <li key={level.type}><span>{level.type.replace("_", " ")}</span><strong>{price(level.price)}</strong><small>{level.state}</small></li>)}</ul></article>
        <article><p className="detail-label">Fair value gaps</p><ul className="level-list">{selected.fvg.slice(-3).reverse().map((gap, index) => <li key={`${gap.lowerPrice}-${index}`}><span className={gap.direction === "BULLISH" ? "positive" : "negative"}>{gap.direction}</span><strong>{price(gap.lowerPrice)}–{price(gap.upperPrice)}</strong><small>{gap.mitigated ? "mitigated" : "open"}</small></li>)}{selected.fvg.length === 0 && <li>No current FVGs</li>}</ul></article>
        <article className="setup-card"><p className="detail-label">Trade gate</p>{selected.setup ? <><p className="setup-direction">{selected.setup.direction} · {selected.setup.riskReward}R</p><dl><div><dt>Entry</dt><dd>{price(selected.setup.preferredEntry)}</dd></div><div><dt>Stop</dt><dd>{price(selected.setup.stopLoss)}</dd></div><div><dt>Targets</dt><dd>{selected.setup.targets.map(price).join(" / ")}</dd></div><div><dt>$10k risk</dt><dd>${selected.setup.risk.riskUSD} · {selected.setup.risk.contracts} contracts</dd></div></dl></> : <p className="no-setup">No validated setup. The confluence gate prevents an entry until its conditions are met.</p>}</article>
      </section>}
    </>}
    <p className="disclaimer">Simulation is deterministic development data, not live quotes. Educational analysis only; no execution or guarantees.</p>
  </main>;
}
