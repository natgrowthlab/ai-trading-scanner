import { NextResponse } from "next/server";

export const runtime = "nodejs";

export function GET() {
  const webhookConfigured = Boolean(process.env.TRADINGVIEW_WEBHOOK_SECRET);
  const telegramConfigured = Boolean(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID);
  const storageConfigured = Boolean(process.env.DATABASE_HOST && process.env.DATABASE_NAME && process.env.DATABASE_USER && process.env.DATABASE_PASSWORD);
  return NextResponse.json({ status: "ok", dataProvider: "MOCK", tradingViewWebhook: webhookConfigured ? "CONFIGURED" : "NOT_CONFIGURED", telegram: telegramConfigured ? "CONFIGURED" : "NOT_CONFIGURED", signalStorage: storageConfigured ? "MYSQL" : "EPHEMERAL_RUNTIME", checkedAt: new Date().toISOString() });
}
