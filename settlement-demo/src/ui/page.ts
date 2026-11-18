import { h } from "./dom";
import { icon } from "./icons";
import { footer, pilot, scope } from "./sections";

export type PageRefs = {
  readonly picker: HTMLDivElement;
  readonly input: HTMLInputElement;
  readonly fileList: HTMLUListElement;
  readonly runButton: HTMLButtonElement;
  readonly sampleButton: HTMLButtonElement;
  readonly templateButton: HTMLButtonElement;
  readonly resetButton: HTMLButtonElement;
  readonly status: HTMLParagraphElement;
  readonly result: HTMLDivElement;
  readonly sheet: HTMLElement;
  readonly sheetChip: HTMLSpanElement;
  readonly figureValue: HTMLSpanElement;
  readonly figureSource: HTMLSpanElement;
  readonly stats: HTMLDivElement;
  readonly exportButton: HTMLButtonElement;
  readonly exportNote: HTMLParagraphElement;
};

const ACCEPT = ".xlsx,.csv";

function navBar(): HTMLElement {
  return h(
    "header",
    { className: "nav container" },
    h(
      "div",
      { className: "nav__pill" },
      h("a", { className: "brand", href: "#top" }, "정산 한 장"),
      h(
        "nav",
        { className: "nav__links", "aria-label": "페이지 내 이동" },
        h("a", { href: "#work" }, "정산하기"),
        h("a", { href: "#scope" }, "계산 범위"),
        h("a", { href: "#pilot" }, "파일럿 제안"),
      ),
      h("span", { className: "chip chip--muted" }, icon("lockSimple"), "브라우저에서만 처리"),
    ),
  );
}

function hero(): HTMLElement {
  return h(
    "section",
    { className: "hero", "aria-labelledby": "hero-title" },
    h("span", { className: "eyebrow" }, "가상 샘플로 확인하는 프로토타입"),
    h("h1", { id: "hero-title" },
      h("span", { className: "hero__line" }, "주문 파일 여러 장을,"),
      h("span", { className: "hero__line" }, "정산 한 장으로."),
    ),
    h(
      "p",
      {},
      "xlsx나 CSV 주문표를 올리면 완료 주문 기준 예상 정산액을 계산하고 정리된 엑셀로 내려받습니다. 파일은 이 브라우저 안에서만 처리됩니다.",
    ),
  );
}

function picker(): Pick<
  PageRefs,
  "picker" | "input" | "fileList" | "runButton" | "sampleButton" | "templateButton" | "resetButton"
> {
  const input = h("input", {
    className: "picker__input",
    type: "file",
    id: "order-files",
    multiple: true,
    accept: ACCEPT,
    "aria-describedby": "picker-hint",
  });
  const fileList = h("ul", { className: "picker__files", "aria-label": "선택한 파일" });
  const runButton = h("button", { className: "btn btn--primary", type: "button", disabled: true }, icon("uploadSimple"), "정산 계산");
  const sampleButton = h("button", { className: "btn btn--secondary", type: "button" }, icon("flask"), "가상 샘플로 계산");
  const templateButton = h("button", { className: "btn btn--secondary", type: "button" }, icon("fileXls"), "샘플 양식 다운로드");
  const resetButton = h("button", { className: "btn btn--secondary", type: "button", disabled: true }, icon("arrowCounterClockwise"), "초기화");
  const pickerElement = h(
    "div",
    { className: "picker" },
    h(
      "label",
      { className: "picker__label", for: "order-files" },
      icon("uploadSimple"),
      h("span", { className: "picker__title" }, "주문 파일을 선택하거나 여기에 놓으세요"),
      h("span", { className: "picker__hint", id: "picker-hint" }, ".xlsx 또는 UTF-8 .csv, 최대 5개, 파일당 5 MiB, 합계 10,000행"),
    ),
    input,
    fileList,
    h("div", { className: "cluster" }, runButton, sampleButton, templateButton, resetButton),
  );
  return { picker: pickerElement, input, fileList, runButton, sampleButton, templateButton, resetButton };
}

const STAT_LABELS = ["전체 주문", "완료 주문", "취소 주문 (제외)", "상품 판매액", "할인액", "배송비", "수수료"] as const;

export function statTile(label: string, value: string, empty: boolean): HTMLDivElement {
  return h(
    "div",
    { className: "stat" },
    h("span", { className: empty ? "stat__value is-empty" : "stat__value" }, value),
    h("span", { className: "stat__label" }, label),
  );
}

function sheet(): Pick<PageRefs, "sheet" | "sheetChip" | "figureValue" | "figureSource" | "stats" | "exportButton" | "exportNote"> {
  const sheetChip = h("span", { className: "chip chip--muted" }, "대기 중");
  const figureValue = h("span", { className: "sheet__figure-value is-empty num" }, "-");
  const figureSource = h("span", { className: "sheet__source" }, "파일을 올리거나 가상 샘플로 계산하면 표시됩니다.");
  const stats = h("div", { className: "stats" }, ...STAT_LABELS.map((label) => statTile(label, "-", true)));
  const exportButton = h(
    "button",
    { className: "btn btn--primary", type: "button", disabled: true, "aria-describedby": "export-note" },
    icon("downloadSimple"),
    "정산 엑셀 다운로드",
  );
  const exportNote = h("p", { className: "sheet__note", id: "export-note" }, "검증을 통과한 결과만 내려받을 수 있습니다.");
  const sheetElement = h(
    "aside",
    { className: "sheet", "aria-labelledby": "sheet-title" },
    h("div", { className: "sheet__head" }, h("h2", { id: "sheet-title" }, "정산 요약"), sheetChip),
    h(
      "div",
      { className: "sheet__figure", "aria-live": "polite", "aria-atomic": "true" },
      h("span", { className: "sheet__figure-label" }, "예상 정산액 (완료 주문 기준)"),
      figureValue,
      figureSource,
    ),
    stats,
    h("p", { className: "sheet__formula" }, "수량 × 판매단가 − 할인액 + 배송비 − 수수료. 완료 주문만 합산하며 이익이나 실제 입금액이 아닙니다."),
    h("div", { className: "sheet__actions" }, exportButton, exportNote),
  );
  return { sheet: sheetElement, sheetChip, figureValue, figureSource, stats, exportButton, exportNote };
}

export function buildPage(root: HTMLElement): PageRefs {
  const pickerRefs = picker();
  const sheetRefs = sheet();
  const status = h("p", { className: "status", role: "status", "aria-live": "polite" });
  const result = h("div", { id: "result" });
  const main = h(
    "main",
    { className: "container", id: "top" },
    hero(),
    h(
      "section",
      { className: "work", id: "work", "aria-label": "정산 작업" },
      h("div", { className: "work__main" }, pickerRefs.picker, status, result),
      sheetRefs.sheet,
    ),
    scope(),
    pilot(),
  );
  root.replaceChildren(navBar(), main, footer());
  return { ...pickerRefs, ...sheetRefs, status, result };
}
