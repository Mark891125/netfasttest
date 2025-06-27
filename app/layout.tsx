import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Network Speed Test",
  description: "Test your network speed with this tool",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`app`}>{children}</body>
    </html>
  );
}
