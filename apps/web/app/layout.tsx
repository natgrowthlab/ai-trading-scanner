import type { Metadata } from "next";
import "./styles.css";
export const metadata: Metadata = { title: "AI Market Scanner", description: "Private market analysis" };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
