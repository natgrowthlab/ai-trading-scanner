"use client";

import { useEffect, useState } from "react";

type Signal = { id: number; symbol: string; direction: string; score: number; entry: string; status: string };

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
  if (!signals.length) return <p className="empty">No validated signals have been recorded.</p>;
  return <div className="table-wrap"><table><caption className="sr-only">Validated signals</caption><thead><tr><th>Symbol</th><th>Direction</th><th>Score</th><th>Entry</th><th>Status</th></tr></thead><tbody>{signals.map((signal) => <tr key={signal.id}><td>{signal.symbol}</td><td>{signal.direction}</td><td>{signal.score}</td><td>{signal.entry}</td><td>{signal.status}</td></tr>)}</tbody></table></div>;
}
