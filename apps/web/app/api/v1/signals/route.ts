import { NextResponse } from "next/server";
import { listTradingViewSignals } from "../../../../lib/tradingview-signals";

export const runtime = "nodejs";

export async function GET() {
  try { return NextResponse.json(await listTradingViewSignals()); }
  catch { return NextResponse.json({ detail: "Signal storage unavailable" }, { status: 503 }); }
}
