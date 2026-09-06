"use client";

import { useEffect, useState } from "react";

type Signal = { id: number; symbol: string; direction: "LONG" | "SHORT"; score: number; entry: string; stopLoss: string; tp1: string; tp2: string; tp3: string; riskUsd: number; timeframe: string; status: string; receivedAt: string };

function receivedAt(timestamp: string) {
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(timestamp));
}

export function SignalTable() {
  const [signals, setSignals] = useState<Signal[] | null>(null);
  const [error, setError] = useState(false);
  useEffect(() => {
    let active = true;
    const load = () => fetch("/api/v1/signals")
      .then((response) => response.ok ? response.json() : Promise.reject(response))
      .then((nextSignals) => {
        if (!active) return;
        setSignals(nextSignals);
        setError(false);
      })
      .catch(() => active && setError(true));

    void load();
    const interval = window.setInterval(() => void load(), 10_000);
    return () => {
      active = false;
      window.clearInterval(interval);
    };
  }, []);
  if (error) return <p className="empty">Signal history is unavailable. Check the API connection.</p>;
  if (signals === null) return <p className="empty">Loading signal history…</p>;
  if (!signals.length) return <div className="empty-state"><p>No validated signals have been recorded.</p><small>A signal appears only after TradingView sends a valid, authenticated webhook. Chart labels by themselves do not create records.</small></div>;
  return <div className="table-wrap"><table><caption className="sr-only">Validated signals and risk targets</caption><thead><tr><th>Market</th><th>Direction</th><th>Entry</th><th>Stop loss</th><th>TP1</th><th>TP2</th><th>TP3</th><th>Risk</th><th>Received</th></tr></thead><tbody>{signals.map((signal) => <tr key={signal.id}><td><strong>{signal.symbol}</strong><small className="table-meta">{signal.timeframe} · {signal.status}</small></td><td><span className={signal.direction === "LONG" ? "signal-pill long" : "signal-pill short"}>{signal.direction === "LONG" ? "BUY / LONG" : "SELL / SHORT"}</span></td><td>{signal.entry}</td><td className="stop-price">{signal.stopLoss}</td><td className="target-price">{signal.tp1}</td><td className="target-price">{signal.tp2}</td><td className="target-price">{signal.tp3}</td><td>${signal.riskUsd.toFixed(2)}</td><td><time dateTime={signal.receivedAt}>{receivedAt(signal.receivedAt)}</time></td></tr>)}</tbody></table></div>;
}
