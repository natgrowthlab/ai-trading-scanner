import { NextRequest, NextResponse } from "next/server";
import { evaluateBtc5mReadiness } from "../../../../../lib/polymarket-readiness";
import { listReadinessReviews, persistReadinessReview } from "../../../../../lib/polymarket-review-store";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  let payload: Record<string, unknown>;
  let input: { marketActive: boolean; secondsRemaining: number; btcMoveUsd: number; selectedSidePrice: number };
  try {
    payload = await request.json();
    if (typeof payload.marketActive !== "boolean" || !["secondsRemaining", "btcMoveUsd", "selectedSidePrice"].every((key) => typeof payload[key] === "number" && Number.isFinite(payload[key]))) throw new Error("invalid");
    input = { marketActive: payload.marketActive, secondsRemaining: payload.secondsRemaining as number, btcMoveUsd: payload.btcMoveUsd as number, selectedSidePrice: payload.selectedSidePrice as number };
    if (input.secondsRemaining < 0 || input.secondsRemaining > 300 || Math.abs(input.btcMoveUsd) > 1_000_000 || input.selectedSidePrice < 0 || input.selectedSidePrice > 1) throw new Error("invalid");
  } catch {
    return NextResponse.json({ detail: "Invalid BTC 5m readiness payload" }, { status: 400 });
  }
  const result = evaluateBtc5mReadiness(input);
  try { return NextResponse.json({ ...result, review: await persistReadinessReview(input, result) }); }
  catch { return NextResponse.json({ detail: "Readiness review storage unavailable" }, { status: 503 }); }
}

export async function GET() {
  try { return NextResponse.json(await listReadinessReviews()); }
  catch { return NextResponse.json({ detail: "Readiness review storage unavailable" }, { status: 503 }); }
}
