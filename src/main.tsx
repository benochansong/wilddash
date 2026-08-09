import { createRoot } from "react-dom/client";
import Home from "../app/page";
import "../app/globals.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("게임 화면을 시작할 루트 요소가 없습니다.");
}

createRoot(root).render(<Home />);
