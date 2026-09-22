import { NextResponse } from "next/server";
import { verifyTestnetCredentials } from "../../../../../../lib/binance-futures-testnet";

export const runtime = "nodejs";

export async function GET() {
  return NextResponse.json(await verifyTestnetCredentials(), { headers: { "Cache-Control": "no-store" } });
}
