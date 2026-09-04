import type { Metadata } from "next";
import { Navigation } from "../components/navigation";
import "./styles.css";
export const metadata: Metadata = { title: "AI Market Scanner", description: "Private market analysis" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body><header><LinkLogo /><Navigation /></header>{children}</body></html>;
}

function LinkLogo() { return <a className="brand" href="/dashboard">AI MARKET SCANNER</a>; }
