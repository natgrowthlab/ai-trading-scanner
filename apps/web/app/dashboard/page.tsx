"use client";

import { useEffect, useState } from "react";

type Status = { dataProvider: string; tradingViewWebhook: string; telegram: string; signalStorage: string };
const modules = [["Market data", "Deterministic MOCK candles are active until a licensed source is connected."], ["Scanner", "Confluence and risk gates are available for NQ, ES, YM, RTY and GC."], ["Execution", "Disabled. This application does not place orders."]];

export default function DashboardPage() {
  const [status, setStatus] = useState<Status | null>(null);
  useEffect(() => { fetch("/api/v1/status").then(response => response.ok ? response.json() : Promise.reject(response)).then(setStatus).catch(() => setStatus(null)); }, []);
  return <main><p className="eyebrow">AI MARKET SCANNER / DASHBOARD</p><h1>Operational foundation</h1><p className="lead">System status is shown without exposing credentials, webhook secrets, or Telegram tokens.</p><section>{modules.map(([title, detail]) => <article key={title}><strong>{title}</strong><p>{detail}</p></article>)}</section><section className="status-grid" aria-label="Integration status">{status ? <><article><p className="detail-label">Data provider</p><strong className="status-value warning">{status.dataProvider}</strong><p>Clearly labelled development data.</p></article><article><p className="detail-label">TradingView webhook</p><strong className={status.tradingViewWebhook === "CONFIGURED" ? "status-value ready" : "status-value pending"}>{status.tradingViewWebhook}</strong><p>Authentication state only; the secret remains private.</p></article><article><p className="detail-label">Telegram</p><strong className={status.telegram === "CONFIGURED" ? "status-value ready" : "status-value pending"}>{status.telegram}</strong><p>Delivery configuration only; no token is displayed.</p></article><article><p className="detail-label">Signal storage</p><strong className="status-value warning">{status.signalStorage.replaceAll("_", " ")}</strong><p>Connect a database before using signal history as a permanent journal.</p></article></> : <article><p className="empty">Status is loading or temporarily unavailable.</p></article>}</section><p className="disclaimer">Historical performance does not guarantee future results. No trade execution is enabled.</p></main>;
}
