import { NextRequest, NextResponse } from "next/server";
import { loadBinanceMarket, parseInterval, parseSymbol } from "../../../../../lib/binance";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  const symbol = parseSymbol(request.nextUrl.searchParams.get("symbol"));
  const interval = parseInterval(request.nextUrl.searchParams.get("interval"));
  try {
    const snapshot = await loadBinanceMarket(symbol, interval);
    return NextResponse.json(snapshot, { headers: { "Cache-Control": "public, s-maxage=5, stale-while-revalidate=25" } });
  } catch {
    return NextResponse.json({ detail: "Live Binance Futures data is temporarily unavailable. Try again shortly." }, { status: 502 });
  }
}
