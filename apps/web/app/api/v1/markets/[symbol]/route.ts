import { NextRequest, NextResponse } from "next/server";
import { analyzeMarket } from "../../../../../lib/market-intelligence";

export const runtime = "nodejs";

export function GET(request: NextRequest, { params }: { params: Promise<{ symbol: string }> }) {
  return params.then(({ symbol }) => {
    try { return NextResponse.json(analyzeMarket(symbol.toUpperCase(), request.nextUrl.searchParams.get("timeframe") ?? "5m")); }
    catch { return NextResponse.json({ detail: "Unsupported market or timeframe" }, { status: 400 }); }
  });
}
