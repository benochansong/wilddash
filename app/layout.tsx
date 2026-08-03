import type { Metadata } from "next";
import { headers } from "next/headers";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("host") ?? "wild-dash-50.bethbes6126.chatgpt.site";
  const origin = `${host.startsWith("localhost") ? "http" : "https"}://${host}`;
  const title = "WILD DASH 50 | 동물 서바이벌 레이싱";
  const description = "몸통박치기와 방해 아이템을 뚫고 50마리의 우당탕탕 레이스에서 살아남으세요!";
  return {
    title,
    description,
    openGraph: { title, description, images: [{ url: `${origin}/og.png`, width: 1672, height: 941, alt: "WILD DASH 50 난장판 동물 레이싱" }] },
    twitter: { card: "summary_large_image", title, description, images: [`${origin}/og.png`] },
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ko"><body>{children}</body></html>;
}
