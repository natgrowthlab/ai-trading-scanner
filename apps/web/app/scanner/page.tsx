"use client";

import { useEffect, useState } from "react";

type Scan = { symbol: string; dataStatus: string; currentPrice: number; bias: { direction: string; score: number }; confidence: { score: number }; setup: { direction: string; riskReward: number } | null };

export default function ScannerPage() {
  const [rows, setRows] = useState<Scan[] | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    const base = process.env.NEXT_PUBLIC_API_BASE_URL ?? "/api/v1";
    fetch(`${base}/scanner?timeframe=5m`).then(r => r.ok ? r.json() : Promise.reject(r)).then(setRows).catch(() => setError(true));
  }, []);
  return <main><p className="eyebrow">MARKET INTELLIGENCE</p><h1>Futures scanner</h1><p className="lead">Confluence-only analysis for NQ, ES, YM, RTY and GC. The data status is always explicit.</p>{error ? <p className="empty">Scanner API unavailable. Check the active Web App deployment.</p> : rows === null ? <p className="empty">Loading scanner…</p> : <div className="table-wrap"><table><caption className="sr-only">Market intelligence scanner</caption><thead><tr><th>Market</th><th>Price</th><th>Bias</th><th>Confidence</th><th>Setup</th><th>Data</th></tr></thead><tbody>{rows.map(row => <tr key={row.symbol}><td>{row.symbol}</td><td>{row.currentPrice}</td><td>{row.bias.direction} · {row.bias.score}</td><td>{row.confidence.score}</td><td>{row.setup ? `${row.setup.direction} · ${row.setup.riskReward}R` : "No confirmed setup"}</td><td>{row.dataStatus}</td></tr>)}</tbody></table></div>}<p className="disclaimer">MOCK is deterministic development data, not live quotes. Educational analysis only; no execution or guarantees.</p></main>;
}
