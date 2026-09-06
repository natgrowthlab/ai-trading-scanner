const safeguards = [
  ["Execution", "Disabled", "This scanner never places Polymarket orders."],
  ["Market", "BTC 5-minute Up/Down", "Reference strategy: momentum into the event close."],
  ["Use", "Research only", "Review market timing, impulse, liquidity and skew before any independent decision."],
  ["Credentials", "Not configured", "No wallet, API key, private key or Polymarket credential is stored in this app."],
];

export default function PolymarketPage() {
  return <main>
    <p className="eyebrow">AI MARKET SCANNER / POLYMARKET</p>
    <h1>BTC 5m strategy reference</h1>
    <p className="lead">The <a href="https://github.com/Novals83/5min-btc-polymarket" target="_blank" rel="noreferrer">5min-btc-polymarket</a> repository is included as an isolated reference module. Its execution tooling is deliberately not connected to this hosted scanner.</p>
    <section className="status-grid" aria-label="Polymarket integration status">
      {safeguards.map(([title, status, detail]) => <article key={title}>
        <p className="detail-label">{title}</p>
        <strong className={status === "Disabled" || status === "Not configured" ? "status-value pending" : "status-value ready"}>{status}</strong>
        <p>{detail}</p>
      </article>)}
    </section>
    <section>
      <article>
        <strong>Integration boundary</strong>
        <p>The external module stays separate from the web app and requires its own execution stack. Any future broker or Polymarket connection must be added explicitly, with dry-run validation and independent risk approval.</p>
      </article>
    </section>
    <PolymarketReadiness />
    <p className="disclaimer">This page is an operational reference, not a trading recommendation. Prediction-market trading can result in loss of capital.</p>
  </main>;
}
import { PolymarketReadiness } from "../../components/polymarket-readiness";
