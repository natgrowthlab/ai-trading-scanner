import { SignalTable } from "../../components/signal-table";

export default function SignalsPage() {
  return <main><p className="eyebrow">SIGNALS</p><h1>Signal history</h1><p className="lead">Only validated, persisted signals appear here. No simulated trades or outcomes are shown.</p><SignalTable /><p className="disclaimer">Quant score and AI confidence are always separate.</p></main>;
}
