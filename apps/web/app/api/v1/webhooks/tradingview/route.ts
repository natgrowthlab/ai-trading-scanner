import { NextRequest, NextResponse } from "next/server";
import { ingestTradingViewPayload } from "../../../../../lib/tradingview-signals";

export const runtime = "nodejs";
const MAX_PAYLOAD_BYTES = 8_192;

export async function POST(request: NextRequest) {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) return NextResponse.json({ detail: "Content-Type must be application/json" }, { status: 415 });
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (declaredLength > MAX_PAYLOAD_BYTES) return NextResponse.json({ detail: "Payload too large" }, { status: 413 });
  let payload: unknown;
  try {
    const body = await request.text();
    if (Buffer.byteLength(body, "utf8") > MAX_PAYLOAD_BYTES) return NextResponse.json({ detail: "Payload too large" }, { status: 413 });
    payload = JSON.parse(body);
  } catch { return NextResponse.json({ detail: "Invalid JSON" }, { status: 400 }); }
  try {
    const result = await ingestTradingViewPayload(payload as Record<string, unknown>);
    return NextResponse.json(result, { status: 202 });
  } catch (error) {
    return NextResponse.json({ detail: error instanceof Error && error.message === "unauthorized" ? "Invalid webhook signature" : "Invalid webhook payload" }, { status: error instanceof Error && error.message === "unauthorized" ? 401 : 422 });
  }
}
