import { timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import { getTestnetAccountSnapshot } from "../../../../../../lib/binance-futures-testnet";

export const dynamic = "force-dynamic";

function authorized(request: Request) { const expected = process.env.BINANCE_DASHBOARD_ACCESS_TOKEN; const received = request.headers.get("x-dashboard-access-token"); if (!expected || !received) return false; const expectedBuffer = Buffer.from(expected); const receivedBuffer = Buffer.from(received); return expectedBuffer.length === receivedBuffer.length && timingSafeEqual(expectedBuffer, receivedBuffer); }
export async function GET(request: Request) { if (!process.env.BINANCE_DASHBOARD_ACCESS_TOKEN) return NextResponse.json({ error: "Account panel is not configured." }, { status: 503 }); if (!authorized(request)) return NextResponse.json({ error: "Account panel access is unauthorized." }, { status: 401 }); try { return NextResponse.json(await getTestnetAccountSnapshot(), { headers: { "Cache-Control": "no-store" } }); } catch { return NextResponse.json({ error: "Unable to load Binance Futures Testnet account data." }, { status: 502 }); } }
