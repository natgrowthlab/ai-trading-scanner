import { NextRequest, NextResponse } from "next/server";
import { evaluatePropAccount } from "../../../../../lib/market-intelligence";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  try {
    const payload = await request.json();
    if (!["accountSize", "currentBalance", "maxDailyLoss", "maxTotalLoss", "dailyLoss", "totalDrawdown"].every(key => typeof payload[key] === "number")) throw new Error();
    return NextResponse.json(evaluatePropAccount(payload));
  } catch { return NextResponse.json({ detail: "Invalid prop-account evaluation payload" }, { status: 400 }); }
}
