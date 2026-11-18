import type { Issue, Order } from "../settlement";
import { h } from "./dom";
import { formatCount, formatKrw } from "./format";
import { icon } from "./icons";

export const PREVIEW_ROWS = 50;
export const ISSUE_ROWS = 200;

export function issueList(issues: readonly Issue[]): HTMLElement {
  const shown = issues.slice(0, ISSUE_ROWS);
  const hidden = issues.length - shown.length;
  return h(
    "section",
    { className: "issues", role: "alert", "aria-labelledby": "issues-title" },
    h(
      "h3",
      { className: "issues__head", id: "issues-title", tabindex: "-1" },
      icon("warningCircle"),
      `다운로드를 막은 문제 ${formatCount(issues.length, "건")}`,
    ),
    h("p", { className: "issues__lead" }, "아래 항목을 원본 파일에서 고친 뒤 다시 선택해 주세요. 문제가 남아 있는 동안에는 어떤 합계도 내보내지 않습니다."),
    h(
      "ol",
      { className: "issues__list" },
      ...shown.map((issue) =>
        h(
          "li",
          { className: "issue" },
          h(
            "span",
            { className: "issue__where" },
            h("span", {}, issue.file === "" ? "파일 전체" : issue.file),
            issue.row > 0 ? h("span", { className: "issue__row num" }, `${issue.row}행`) : null,
          ),
          h("span", {}, issue.message),
        ),
      ),
    ),
    hidden > 0 ? h("p", { className: "issues__lead" }, `그 외 ${formatCount(hidden, "건")}은 위 항목을 고친 뒤 다시 확인해 주세요.`) : null,
  );
}

// Per-row figure follows the CONTRACT formula; totals always come from the core summary.
function expectedFor(order: Order): number {
  return order.status === "완료" ? order.quantity * order.unitPrice - order.discount + order.shipping - order.fee : 0;
}

const COLUMNS: readonly { readonly label: string; readonly numeric: boolean }[] = [
  { label: "주문번호", numeric: false },
  { label: "주문일", numeric: false },
  { label: "상품명", numeric: false },
  { label: "수량", numeric: true },
  { label: "판매단가", numeric: true },
  { label: "할인액", numeric: true },
  { label: "배송비", numeric: true },
  { label: "수수료", numeric: true },
  { label: "상태", numeric: false },
  { label: "예상 정산액", numeric: true },
  { label: "원본 파일", numeric: false },
];

function orderRow(order: Order): HTMLTableRowElement {
  const cell = (text: string, numeric = false): HTMLTableCellElement => h("td", { className: numeric ? "is-num" : undefined }, text);
  return h(
    "tr",
    { className: order.status === "취소" ? "is-canceled" : undefined },
    cell(order.id),
    cell(order.date),
    cell(order.product),
    cell(formatCount(order.quantity, ""), true),
    cell(formatKrw(order.unitPrice), true),
    cell(formatKrw(order.discount), true),
    cell(formatKrw(order.shipping), true),
    cell(formatKrw(order.fee), true),
    h("td", {}, h("span", { className: "chip chip--muted" }, order.status)),
    cell(formatKrw(expectedFor(order)), true),
    cell(order.source),
  );
}

export function previewTable(orders: readonly Order[], sample: boolean): HTMLElement {
  const shown = orders.slice(0, PREVIEW_ROWS);
  const hidden = orders.length - shown.length;
  const caption =
    hidden > 0
      ? `주문 ${formatCount(orders.length, "건")} 중 처음 ${formatCount(shown.length, "건")}만 표시. 합계와 다운로드는 전체 기준.`
      : `주문 ${formatCount(orders.length, "건")} 전체 표시.`;
  return h(
    "div",
    { className: "preview" },
    h(
      "div",
      { className: "preview__head" },
      h("h3", {}, sample ? "가상 샘플 주문 미리보기" : "주문 미리보기"),
      h("span", { className: "preview__count" }, caption),
    ),
    h(
      "div",
      { className: "table-wrap", tabindex: "0", role: "region", "aria-label": "주문 미리보기 표, 가로로 스크롤할 수 있습니다" },
      h(
        "table",
        { className: "table" },
        h("caption", {}, caption),
        h("thead", {}, h("tr", {}, ...COLUMNS.map((column) => h("th", { scope: "col", className: column.numeric ? "is-num" : undefined }, column.label)))),
        h("tbody", {}, ...shown.map(orderRow)),
      ),
    ),
  );
}

export function emptyNotice(): HTMLElement {
  return h(
    "p",
    { className: "notice notice--muted" },
    icon("info"),
    h("span", {}, "아직 계산한 결과가 없습니다. 양식이 궁금하면 샘플 양식을 내려받아 열어 보세요."),
  );
}
