const features = ["Binance USDT-M Futures data", "Closed-candle strategy analysis", "Dry-run and Testnet-first controls"];
export default function Home() {
  return <main><p className="eyebrow">BINANCE FUTURES BOT</p><h1>Crypto futures, clearly controlled.</h1><p className="lead">A focused USDT-M Futures workspace for live market analysis and testable bot logic.</p><section>{features.map((feature) => <article key={feature}>{feature}</article>)}</section><p className="disclaimer">Educational and analytical tool. Crypto futures involve substantial risk of loss.</p></main>;
}
