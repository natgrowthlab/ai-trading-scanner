import { NextRequest, NextResponse } from "next/server";
import { listScanner } from "../../../../lib/market-intelligence";

export const runtime = "nodejs";

export function GET(request: NextRequest) {
  try { return NextResponse.json(listScanner(request.nextUrl.searchParams.get("timeframe") ?? "5m")); }
  catch { return NextResponse.json({ detail: "Unsupported timeframe" }, { status: 400 }); }
}
