import { SignalTable } from "../../components/signal-table";

export default function SignalsPage() {
  return <main><p className="eyebrow">SIGNALS</p><h1>Signal history</h1><p className="lead">Only authenticated TradingView webhooks appear here. Each record includes the entry plan and risk targets; it is never an execution command.</p><SignalTable /><p className="disclaimer">Signal records currently use the Web App runtime. For durable history across restarts, connect a managed database before relying on this as a trading journal.</p></main>;
}
