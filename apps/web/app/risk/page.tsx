"use client";

import { FormEvent, useState } from "react";

type FormValues = { accountSize: number; currentBalance: number; maxDailyLoss: number; maxTotalLoss: number; dailyLoss: number; totalDrawdown: number };
type Result = { currentEquity: number; dailyLossRemaining: number; drawdownRemaining: number; riskMultiplier: number; maximumSafeRisk: number; status: "SAFE" | "CAUTION" | "DANGER" | "LOCKED" };

const initial: FormValues = { accountSize: 10000, currentBalance: 10000, maxDailyLoss: 500, maxTotalLoss: 1000, dailyLoss: 0, totalDrawdown: 0 };
const labels: Record<keyof FormValues, string> = { accountSize: "Account size (USD)", currentBalance: "Current equity (USD)", maxDailyLoss: "Maximum daily loss", maxTotalLoss: "Maximum total drawdown", dailyLoss: "Loss used today", totalDrawdown: "Total drawdown used" };
const money = (amount: number) => new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 2 }).format(amount);

export default function RiskPage() {
  const [values, setValues] = useState(initial);
  const [result, setResult] = useState<Result | null>(null);
  const [error, setError] = useState(false);
  async function evaluate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(false);
    const response = await fetch("/api/v1/prop-accounts/evaluate", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(values) });
    if (!response.ok) { setError(true); return; }
    setResult(await response.json());
  }
  return <main className="risk-page"><p className="eyebrow">ACCOUNT SAFETY</p><h1>Risk control</h1><p className="lead">Model the loss limits of a prop account before accepting a signal. This tool never sends an order.</p><div className="risk-layout"><form className="risk-form" onSubmit={evaluate}>{(Object.keys(values) as Array<keyof FormValues>).map(key => <label key={key}>{labels[key]}<input type="number" min="0" step="0.01" value={values[key]} onChange={event => setValues({ ...values, [key]: Number(event.target.value) })} /></label>)}<button type="submit">Evaluate risk</button>{error && <p className="form-error" role="alert">Could not evaluate the account. Try again.</p>}</form><section className="risk-result" aria-live="polite">{result ? <><p className={`risk-status ${result.status.toLowerCase()}`}>{result.status}</p><h2>{money(result.maximumSafeRisk)}</h2><p className="detail-meta">Maximum safe risk for the next trade</p><dl><div><dt>Daily room</dt><dd>{money(result.dailyLossRemaining)}</dd></div><div><dt>Drawdown room</dt><dd>{money(result.drawdownRemaining)}</dd></div><div><dt>Risk multiplier</dt><dd>{Math.round(result.riskMultiplier * 100)}%</dd></div><div><dt>Equity</dt><dd>{money(result.currentEquity)}</dd></div></dl></> : <p className="empty">Enter the account limits and choose <strong>Evaluate risk</strong> to calculate the safe allocation.</p>}</section></div><p className="disclaimer">Risk controls are a planning aid. Follow the exact rules of your prop-firm agreement.</p></main>;
}
