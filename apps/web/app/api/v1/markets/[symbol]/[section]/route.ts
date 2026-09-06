import { NextRequest, NextResponse } from "next/server";
import { analyzeMarket } from "../../../../../../lib/market-intelligence";

export const runtime = "nodejs";
const sections = new Set(["bias", "liquidity", "structure", "sweeps", "fvg", "smt", "setups"]);

export function GET(request: NextRequest, { params }: { params: Promise<{ symbol: string; section: string }> }) {
  return params.then(({ symbol, section }) => {
    try {
      if (!sections.has(section)) return NextResponse.json({ detail: "Unsupported section" }, { status: 404 });
      const result = analyzeMarket(symbol.toUpperCase(), request.nextUrl.searchParams.get("timeframe") ?? "5m");
      const key = section === "setups" ? "setup" : section;
      return NextResponse.json({ dataStatus: result.dataStatus, [key]: result[key as keyof typeof result] });
    } catch { return NextResponse.json({ detail: "Unsupported market or timeframe" }, { status: 400 }); }
  });
}
