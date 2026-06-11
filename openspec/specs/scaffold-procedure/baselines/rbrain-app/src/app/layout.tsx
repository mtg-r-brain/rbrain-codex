import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "rbrain-app",
  description: "Renders the user-facing Next.js application — chat UI, deck builder, blog reader.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
