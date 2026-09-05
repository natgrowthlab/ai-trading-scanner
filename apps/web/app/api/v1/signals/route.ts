import { NextResponse } from "next/server";
import { listTradingViewSignals } from "../../../../lib/tradingview-signals";

export const runtime = "nodejs";

export function GET() {
  return NextResponse.json(listTradingViewSignals());
}
