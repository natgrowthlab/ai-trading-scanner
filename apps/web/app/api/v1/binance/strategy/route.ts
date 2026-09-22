import { NextRequest, NextResponse } from "next/server";
import { loadBinanceMarket, parseInterval, parseSymbol } from "../../../../../lib/binance";
import { evaluateClosedCandleStrategy } from "../../../../../lib/futures-strategy";
export const runtime = "nodejs";
export async function GET(request: NextRequest) { const symbol = parseSymbol(request.nextUrl.searchParams.get("symbol")); const interval = parseInterval(request.nextUrl.searchParams.get("interval")); try { return NextResponse.json(evaluateClosedCandleStrategy(await loadBinanceMarket(symbol, interval)), { headers: { "Cache-Control": "public, s-maxage=5, stale-while-revalidate=25" } }); } catch { return NextResponse.json({ detail: "Strategy data is temporarily unavailable." }, { status: 502 }); } }
