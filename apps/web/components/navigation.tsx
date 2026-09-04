import Link from "next/link";

const links = [
  ["/dashboard", "Dashboard"],
  ["/scanner", "Scanner"],
  ["/signals", "Signals"],
];

export function Navigation() {
  return <nav aria-label="Main navigation">{links.map(([href, label]) => <Link key={href} href={href}>{label}</Link>)}</nav>;
}
