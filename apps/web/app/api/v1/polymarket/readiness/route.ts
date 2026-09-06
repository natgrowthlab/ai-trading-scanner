import { NextRequest, NextResponse } from "next/server";
import { evaluateBtc5mReadiness } from "../../../../../lib/polymarket-readiness";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  try {
    const payload = await request.json();
    if (typeof payload.marketActive !== "boolean" || !["secondsRemaining", "btcMoveUsd", "selectedSidePrice"].every((key) => typeof payload[key] === "number" && Number.isFinite(payload[key]))) throw new Error("invalid");
    if (payload.secondsRemaining < 0 || payload.secondsRemaining > 300 || Math.abs(payload.btcMoveUsd) > 1_000_000 || payload.selectedSidePrice < 0 || payload.selectedSidePrice > 1) throw new Error("invalid");
    return NextResponse.json(evaluateBtc5mReadiness(payload));
  } catch {
    return NextResponse.json({ detail: "Invalid BTC 5m readiness payload" }, { status: 400 });
  }
}
