import { utils, write, type WorkBook, type WorkSheet } from "xlsx";
import { HEADERS, type Settlement } from "./settlement";
import { SAMPLE_ROWS } from "./samples";

function encode(workbook: WorkBook): Uint8Array<ArrayBuffer> {
  const bytes: unknown = write(workbook, { type: "array", bookType: "xlsx" });
  if (bytes instanceof ArrayBuffer) return new Uint8Array(bytes);
  if (bytes instanceof Uint8Array) return new Uint8Array(bytes);
  throw new TypeError("The XLSX encoder returned an unsupported binary type.");
}

export function createSampleWorkbook(): Uint8Array<ArrayBuffer> {
  const workbook = utils.book_new();
  const sheet = utils.aoa_to_sheet(SAMPLE_ROWS.map((row) => [...row]));
  sheet["!cols"] = HEADERS.map(() => ({ wch: 20 }));
  utils.book_append_sheet(workbook, sheet, "주문");
  return encode(workbook);
}

export function createReportWorkbook(result: Extract<Settlement, { kind: "valid" }>): Uint8Array<ArrayBuffer> {
  const workbook = utils.book_new();
  const rows = result.orders.map((order) => [
    order.id, order.date, order.product, order.quantity, order.unitPrice,
    order.discount, order.shipping, order.fee, order.status,
    order.quantity * order.unitPrice,
    order.status === "완료" ? order.quantity * order.unitPrice - order.discount + order.shipping - order.fee : 0,
    order.source,
  ]);
  const detail = utils.aoa_to_sheet([[...HEADERS, "상품 판매액", "예상 정산액", "원본 파일"], ...rows]);
  for (const [index, order] of result.orders.entries()) {
    const row = index + 2;
    detail[`J${row}`] = { t: "n", f: `D${row}*E${row}`, v: order.quantity * order.unitPrice, z: "#,##0" };
    detail[`K${row}`] = {
      t: "n", f: `IF(I${row}="완료",J${row}-F${row}+G${row}-H${row},0)`,
      v: order.status === "완료" ? order.quantity * order.unitPrice - order.discount + order.shipping - order.fee : 0,
      z: "#,##0",
    };
  }
  detail["!cols"] = [...HEADERS, "", "", ""].map((_, index) => ({ wch: index === 2 || index === 11 ? 30 : 18 }));
  detail["!autofilter"] = { ref: `A1:L${rows.length + 1}` };
  const end = rows.length + 1;
  const summary: WorkSheet = utils.aoa_to_sheet([
    ["항목", "금액 / 건수"],
    ["전체 주문 수", result.summary.orderCount],
    ["완료 주문 수", result.summary.completedCount],
    ["취소 주문 수 (합계 제외)", result.summary.canceledCount],
    ["상품 판매액 (완료)", result.summary.gross],
    ["할인액 (완료)", result.summary.discount],
    ["배송비 (완료)", result.summary.shipping],
    ["수수료 (완료)", result.summary.fee],
    ["예상 정산액 (원)", result.summary.expected],
  ]);
  summary["B2"] = { t: "n", f: `COUNTA('정산내역'!A2:A${end})`, v: result.summary.orderCount };
  summary["B3"] = { t: "n", f: `COUNTIF('정산내역'!I2:I${end},"완료")`, v: result.summary.completedCount };
  summary["B4"] = { t: "n", f: `COUNTIF('정산내역'!I2:I${end},"취소")`, v: result.summary.canceledCount };
  for (const [index, column] of ["J", "F", "G", "H"].entries()) {
    const values = [result.summary.gross, result.summary.discount, result.summary.shipping, result.summary.fee];
    summary[`B${index + 5}`] = {
      t: "n", f: `SUMIF('정산내역'!I2:I${end},"완료",'정산내역'!${column}2:${column}${end})`,
      v: values[index], z: "#,##0",
    };
  }
  summary["B9"] = { t: "n", f: `SUM('정산내역'!K2:K${end})`, v: result.summary.expected, z: "#,##0" };
  summary["!cols"] = [{ wch: 30 }, { wch: 24 }];
  utils.book_append_sheet(workbook, summary, "정산요약");
  utils.book_append_sheet(workbook, detail, "정산내역");
  const guide = utils.aoa_to_sheet([
    ["항목", "설명"],
    ["계산", "완료 주문의 수량 × 판매단가 − 할인액 + 배송비 − 수수료. 모든 금액은 원(KRW)."],
    ["주의", "예상 정산액은 이익·세금 신고액·실제 입금액이 아닙니다. 매입비, 세금, 부분환불은 계산하지 않습니다."],
    ["입력", "정산내역 A:I는 입력값, J:K와 정산요약 B열은 계산식입니다. 주문번호·날짜는 텍스트로 유지합니다."],
    ["편집", "기존 행의 값 수정은 계산식에 반영됩니다. 행 추가·삭제 시 새로 가져와 결과를 다운로드하세요."],
    ["검증", "앱에서 입력을 검증한 결과입니다. Excel에서 직접 바꾼 값은 앱 검증을 거치지 않습니다."],
    ["샘플", "DEMO-로 시작하는 샘플 주문은 모두 가상 데이터이며 실제 매출이 아닙니다."],
    ["개인정보", "서버 전송 없이 브라우저에서 처리했습니다. 원본 파일명은 추적을 위해 정산내역에 포함됩니다."],
  ]);
  guide["!cols"] = [{ wch: 16 }, { wch: 110 }];
  utils.book_append_sheet(workbook, guide, "사용안내");
  return encode(workbook);
}
