import type { Metadata } from "next";
import "./globals.css";
import packageJson from "../package.json";

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
    <html lang="en" data-v={packageJson.version} data-time={Date.now()}>
      <body className={`app`}>{children}</body>
    </html>
  );
}
