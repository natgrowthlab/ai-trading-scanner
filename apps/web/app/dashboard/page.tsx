const modules = [
  ["Market data", "Assets and canonical candles are available."],
  ["Structure", "Swings, BOS, and CHoCH are calculated deterministically."],
  ["Scanner", "No live signals yet; only validated signals will appear."],
];

export default function DashboardPage() {
  return <main><p className="eyebrow">AI MARKET SCANNER / DASHBOARD</p><h1>Operational foundation</h1><section>{modules.map(([title, detail]) => <article key={title}><strong>{title}</strong><p>{detail}</p></article>)}</section><p className="disclaimer">Quant score and AI confidence remain separate. Historical performance does not guarantee future results.</p></main>;
}
