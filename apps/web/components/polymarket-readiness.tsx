"use client";

import { FormEvent, useState } from "react";

type Readiness = {
  decision: "READY_FOR_REVIEW" | "NOT_READY";
  checks: { label: string; passed: boolean; detail: string }[];
  disclaimer: string;
};

export function PolymarketReadiness() {
  const [result, setResult] = useState<Readiness | null>(null);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setLoading(true);
    setError(false);
    try {
      const response = await fetch("/api/v1/polymarket/readiness", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          marketActive: data.get("marketActive") === "on",
          secondsRemaining: Number(data.get("secondsRemaining")),
          btcMoveUsd: Number(data.get("btcMoveUsd")),
          selectedSidePrice: Number(data.get("selectedSidePrice")),
        }),
      });
      if (!response.ok) throw new Error("request");
      setResult(await response.json());
    } catch {
      setError(true);
    } finally {
      setLoading(false);
    }
  }

  return <section className="readiness-layout" aria-label="BTC 5m readiness evaluator">
    <form className="risk-form" onSubmit={submit}>
      <h2>Readiness evaluator</h2>
      <label className="checkbox-label"><input name="marketActive" type="checkbox" defaultChecked /> Market is active</label>
      <label>Seconds remaining <input name="secondsRemaining" type="number" min="0" max="300" defaultValue="120" required /></label>
      <label>BTC move in this interval (USD) <input name="btcMoveUsd" type="number" step="0.01" defaultValue="70" required /></label>
      <label>Selected side price (0–1) <input name="selectedSidePrice" type="number" min="0" max="1" step="0.01" defaultValue="0.70" required /></label>
      <button type="submit" disabled={loading}>{loading ? "Checking…" : "Check conditions"}</button>
      {error && <p className="form-error">The values could not be evaluated. Check the fields and retry.</p>}
    </form>
    <aside className="risk-result" aria-live="polite">
      <p className={`risk-status ${result?.decision === "READY_FOR_REVIEW" ? "safe" : "caution"}`}>{result?.decision === "READY_FOR_REVIEW" ? "READY FOR REVIEW" : "AWAITING CHECK"}</p>
      <h2>{result?.decision === "READY_FOR_REVIEW" ? "Review conditions met" : "No execution"}</h2>
      {result ? <ul className="readiness-checks">{result.checks.map((check) => <li key={check.label} className={check.passed ? "passed" : "failed"}><strong>{check.passed ? "Pass" : "Review"} · {check.label}</strong><span>{check.detail}</span></li>)}</ul> : <p>Enter observed market values to evaluate the isolated reference rules.</p>}
      <p className="disclaimer">{result?.disclaimer ?? "This page never places orders or accesses Polymarket credentials."}</p>
    </aside>
  </section>;
}
