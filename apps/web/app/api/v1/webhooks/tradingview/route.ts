import { NextRequest, NextResponse } from "next/server";
import { ingestTradingViewPayload } from "../../../../../lib/tradingview-signals";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  let payload: unknown;
  try { payload = await request.json(); } catch { return NextResponse.json({ detail: "Invalid JSON" }, { status: 400 }); }
  try {
    const result = await ingestTradingViewPayload(payload as Record<string, unknown>);
    return NextResponse.json(result, { status: 202 });
  } catch (error) {
    return NextResponse.json({ detail: error instanceof Error && error.message === "unauthorized" ? "Invalid webhook signature" : "Invalid webhook payload" }, { status: error instanceof Error && error.message === "unauthorized" ? 401 : 422 });
  }
}
