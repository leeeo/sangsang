import "pretendard/dist/web/variable/pretendardvariable-dynamic-subset.css";
import "./styles/tokens.css";
import "./styles/app.css";
import { mountApp } from "./ui/app";
import { buildPage } from "./ui/page";

const root = document.getElementById("app");
if (!(root instanceof HTMLElement)) {
  throw new Error("#app root element is missing from index.html.");
}
mountApp(buildPage(root));
