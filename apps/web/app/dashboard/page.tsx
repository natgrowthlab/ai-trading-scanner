"use client";

import { useEffect, useState } from "react";
import { TestnetAccount } from "../../components/testnet-account";

type TestnetStatus = { configured: boolean; authenticated: boolean; message: string };
const modules = [["Live market data", "Binance USDT‑M perpetual ticker, depth and closed candles are read through the server."], ["Strategy", "Trend-pullback logic evaluates closed candles only, keeping each decision testable."], ["Execution", "Testnet authentication is verified server-side. No live order route exists."]];

export default function DashboardPage() {
  const [testnet, setTestnet] = useState<TestnetStatus | null>(null);
  useEffect(() => { let active = true; fetch("/api/v1/binance/futures/testnet-status", { cache: "no-store" }).then((response) => response.json()).then((status: TestnetStatus) => active && setTestnet(status)).catch(() => active && setTestnet({ configured: false, authenticated: false, message: "Testnet status is unavailable." })); return () => { active = false; }; }, []);
  const testnetClass = testnet?.authenticated ? "status-value ready" : testnet?.configured ? "status-value pending" : "status-value warning";
  const testnetLabel = testnet?.authenticated ? "VERIFIED" : testnet?.configured ? "CHECK CREDENTIALS" : "NOT CONFIGURED";
  return <main><p className="eyebrow">BINANCE FUTURES BOT</p><h1>Control center</h1><p className="lead">One product, one market focus: USDT‑M crypto futures. The production interface displays market data without exposing exchange credentials.</p><section>{modules.map(([title, detail]) => <article key={title}><strong>{title}</strong><p>{detail}</p></article>)}</section><section className="status-grid" aria-label="Bot status"><article><p className="detail-label">Market feed</p><strong className="status-value ready">BINANCE FUTURES</strong><p>Public perpetual market data with regional endpoint fallback.</p></article><article><p className="detail-label">Testnet credentials</p><strong className={testnetClass}>{testnetLabel}</strong><p>{testnet?.message ?? "Checking server-side Testnet connection…"}</p></article><article><p className="detail-label">Live execution</p><strong className="status-value pending">DISABLED</strong><p>There is no live order route. Testnet validation comes first.</p></article></section><TestnetAccount /><p className="disclaimer">Crypto futures are high risk. Historical or simulated results never guarantee future outcomes.</p></main>;
}
