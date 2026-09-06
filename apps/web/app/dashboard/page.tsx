"use client";

import { useEffect, useState } from "react";

type Status = { dataProvider: string; tradingViewWebhook: string; telegram: string; signalStorage: string; signalCount: number };
const modules = [["Market data", "Deterministic MOCK candles are active until a licensed source is connected."], ["Scanner", "Confluence and risk gates are available for NQ, ES, YM, RTY and GC."], ["Execution", "Disabled. This application does not place orders."]];

export default function DashboardPage() {
  const [status, setStatus] = useState<Status | null>(null);
  useEffect(() => { fetch("/api/v1/status").then(response => response.ok ? response.json() : Promise.reject(response)).then(setStatus).catch(() => setStatus(null)); }, []);
  const storageClass = status?.signalStorage === "MYSQL_CONNECTED" ? "status-value ready" : status?.signalStorage === "MYSQL_UNAVAILABLE" ? "status-value pending" : "status-value warning";
  return <main><p className="eyebrow">AI MARKET SCANNER / DASHBOARD</p><h1>Operational foundation</h1><p className="lead">System status is shown without exposing credentials, webhook secrets, or Telegram tokens.</p><section>{modules.map(([title, detail]) => <article key={title}><strong>{title}</strong><p>{detail}</p></article>)}</section><section className="status-grid" aria-label="Integration status">{status ? <><article><p className="detail-label">Live signal source</p><strong className="status-value ready">{status.dataProvider.replaceAll("_", " ")}</strong><p>TradingView sends authenticated signal events.</p></article><article><p className="detail-label">TradingView webhook</p><strong className={status.tradingViewWebhook === "CONFIGURED" ? "status-value ready" : "status-value pending"}>{status.tradingViewWebhook}</strong><p>Authentication state only; the secret remains private.</p></article><article><p className="detail-label">Telegram</p><strong className={status.telegram === "CONFIGURED" ? "status-value ready" : "status-value pending"}>{status.telegram}</strong><p>Delivery configuration only; no token is displayed.</p></article><article><p className="detail-label">Signal storage</p><strong className={storageClass}>{status.signalStorage.replaceAll("_", " ")}</strong><p>{status.signalCount} persisted signal{status.signalCount === 1 ? "" : "s"}. MySQL is checked live.</p></article></> : <article><p className="empty">Status is loading or temporarily unavailable.</p></article>}</section><p className="disclaimer">Historical performance does not guarantee future results. No trade execution is enabled.</p></main>;
}
