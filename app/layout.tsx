import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "WILD DASH 50 | 동물 서바이벌 레이싱",
  description: "나만의 엉뚱한 키메라 동물을 만들고 50마리의 우당탕탕 레이스에서 살아남으세요!",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ko"><body>{children}</body></html>;
}
