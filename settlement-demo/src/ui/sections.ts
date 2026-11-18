import { HEADERS } from "../settlement";
import { h } from "./dom";
import { icon } from "./icons";

function bullet(text: string): HTMLLIElement {
  return h("li", {}, icon("check"), h("span", {}, text));
}

function crossed(text: string): HTMLLIElement {
  return h("li", {}, icon("x"), h("span", {}, text));
}

export function scope(): HTMLElement {
  return h(
    "section",
    { className: "section", id: "scope", "aria-labelledby": "scope-title" },
    h(
      "header",
      { className: "section__head" },
      h("h2", { id: "scope-title" }, "계산 범위를 확인하세요"),
      h("p", {}, "이 프로토타입은 정해진 한 가지 양식만 읽습니다. 양식이나 값이 어긋나면 파일 이름과 행 번호를 알려 주고, 그 묶음 전체의 다운로드를 막습니다."),
    ),
    h(
      "div",
      { className: "scope" },
      h(
        "div",
        { className: "scope__card" },
        h("h3", {}, "입력 양식"),
        h("p", { className: "picker__hint" }, "첫 행은 아래 열 이름을 이 순서 그대로 써야 합니다."),
        h("div", { className: "headers" }, ...HEADERS.map((name) => h("code", {}, name))),
        h(
          "ul",
          {},
          bullet("한 행이 주문 한 건입니다. 주문번호는 모든 파일에서 유일해야 합니다."),
          bullet("주문번호와 주문일은 텍스트, 주문일은 2000년부터 2100년 사이의 YYYY-MM-DD 형식입니다."),
          bullet("수량은 1 이상의 정수, 금액은 0 이상의 정수(원)입니다. 할인액은 수량 × 판매단가를 넘을 수 없습니다."),
          bullet("상태는 완료 또는 취소만 허용합니다. 취소 주문은 표에 보이지만 합계에서 뺍니다."),
        ),
      ),
      h(
        "div",
        { className: "scope__card" },
        h("h3", {}, "계산식"),
        h("p", { className: "formula" }, "예상 정산액 = 수량 × 판매단가 − 할인액 + 배송비 − 수수료"),
        h(
          "ul",
          {},
          bullet("완료 상태인 주문만 더합니다."),
          bullet("수수료율을 자동으로 가정하지 않습니다. 수수료 열에 적힌 값만 씁니다."),
          bullet("합계는 예상치이며 이익, 세금 신고액, 실제 입금액과 다릅니다."),
        ),
      ),
      h(
        "div",
        { className: "scope__card" },
        h("h3", {}, "입력 한도"),
        h(
          "ul",
          {},
          bullet("파일 형식은 .xlsx 또는 UTF-8 .csv입니다."),
          bullet("한 번에 최대 5개 파일, 파일당 5 MiB, 전체 10,000행까지입니다."),
          bullet("워크북에는 데이터가 있는 시트가 하나만 있어야 합니다."),
          bullet("수식과 오류 셀은 받지 않습니다. 값만 붙여넣어 주세요."),
        ),
      ),
      h(
        "div",
        { className: "scope__card scope__card--canvas" },
        h("h3", {}, "계산하지 않는 것"),
        h(
          "ul",
          {},
          crossed("부분 환불, 부분 취소"),
          crossed("세금, 매입 원가, 이익 계산"),
          crossed("실제 입금액과의 대사(정산 내역 대조)"),
          crossed("한 주문에 여러 상품이 있는 다품목 주문. 별도 어댑터 합의가 필요합니다."),
          crossed("특정 마켓플레이스 양식 자동 인식"),
        ),
      ),
    ),
  );
}

export function pilot(): HTMLElement {
  const term = (title: string, detail: string): HTMLDivElement =>
    h("div", { className: "pilot__term" }, h("strong", {}, title), h("span", {}, detail));
  return h(
    "section",
    { className: "section", id: "pilot", "aria-labelledby": "pilot-title" },
    h(
      "header",
      { className: "section__head" },
      h("span", { className: "eyebrow" }, "고정 범위 파일럿"),
      h("h2", { id: "pilot-title" }, "정해진 범위로 한 번 해보는 제안"),
      h("p", {}, "샘플 파일을 검토하고 범위를 합의한 뒤에만 시작하는 1회 작업입니다. 아직 아무에게도 검증받지 않은 제안이라 여기 적힌 조건이 전부입니다."),
    ),
    h(
      "div",
      { className: "pilot" },
      h(
        "div",
        { className: "pilot__price" },
        h("span", { className: "pilot__price-value num" }, "150,000원"),
        h("span", { className: "pilot__price-label" }, "고정 범위 1회 작업 기준"),
      ),
      h(
        "div",
        { className: "pilot__terms" },
        term("입력 형식 1종", "합의한 주문표 양식 하나만 처리합니다."),
        term("정산 워크북 1종", "요약, 내역, 사용 안내 시트가 있는 엑셀 파일 하나를 드립니다."),
        term("수정 1회", "첫 산출물에 대한 수정 요청을 한 번 반영합니다."),
        term("영업일 3일 목표", "샘플 검토와 범위 합의가 끝난 뒤부터 계산합니다."),
      ),
      h(
        "p",
        { className: "pilot__caveat" },
        "이 금액은 공개 가격이나 판매 약속이 아니라 검증 전 제안입니다. 이 프로토타입에는 연락, 결제, 가입 기능이 없습니다.",
      ),
    ),
  );
}

export function footer(): HTMLElement {
  return h(
    "footer",
    { className: "footer" },
    h(
      "div",
      { className: "container footer__inner" },
      h("h2", {}, "이 화면이 약속하지 않는 것"),
      h(
        "ul",
        {},
        h("li", {}, "주문 파일은 서버로 보내지 않고 브라우저에 저장하지도 않습니다. 탭을 닫으면 사라집니다."),
        h("li", {}, "가상 샘플의 주문은 모두 만들어 낸 데이터이며 실제 매출이 아닙니다."),
        h("li", {}, "예상 정산액은 이익, 세금 신고 금액, 실제 입금액이 아닙니다."),
        h("li", {}, "특정 마켓플레이스 지원이나 세무·회계상의 정확성을 뜻하지 않습니다."),
      ),
      h("p", { className: "footer__meta" }, "정산 한 장은 임시 이름입니다. 도메인, 호스팅, 결제 없이 로컬에서만 동작하는 프로토타입입니다."),
    ),
  );
}

