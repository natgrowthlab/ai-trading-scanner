import { NextResponse } from "next/server";
export const runtime = "nodejs";

export async function GET() {
  return NextResponse.json({ status: "ok", dataProvider: "BINANCE_USDTM_FUTURES", botMode: "DRY_RUN", execution: "DISABLED", checkedAt: new Date().toISOString() });
}
