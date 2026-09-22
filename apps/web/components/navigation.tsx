import Link from "next/link";

const links = [
  ["/dashboard", "Bot"],
  ["/binance", "Futures"],
  ["/scanner", "Research"],
  ["/risk", "Risk"],
];

export function Navigation() {
  return <nav aria-label="Main navigation">{links.map(([href, label]) => <Link key={href} href={href}>{label}</Link>)}</nav>;
}
