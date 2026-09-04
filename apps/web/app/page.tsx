const features = ["Canonical market data", "Market structure engine", "Deterministic testing"];
export default function Home() {
  return <main><p className="eyebrow">PRIVATE ANALYTICS PLATFORM</p><h1>AI Market Scanner</h1><p className="lead">Phase 1 foundation is running. Signals are not generated at this stage.</p><section>{features.map((feature) => <article key={feature}>{feature}</article>)}</section><p className="disclaimer">Educational and analytical tool. Trading involves risk of loss.</p></main>;
}
