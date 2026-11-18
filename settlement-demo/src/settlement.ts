import { z } from "zod";

export const HEADERS = [
  "주문번호", "주문일", "상품명", "수량", "판매단가",
  "할인액", "배송비", "수수료", "상태",
] as const;
export const MAX_ROWS = 10_000;

function numericCell(value: unknown): unknown {
  if (typeof value !== "string") return value;
  const text = value.trim();
  return /^(?:0|[1-9]\d*|[1-9]\d{0,2}(?:,\d{3})+)$/.test(text)
    ? Number(text.replaceAll(",", ""))
    : value;
}

const money = z.preprocess(numericCell, z.number().int().min(0).max(1_000_000_000)).brand("KRW");
const date = z.string().regex(/^(20\d{2}|2100)-\d{2}-\d{2}$/).refine((value) => {
  const parsed = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
});
const rowSchema = z.tuple([
  z.string().trim().min(1).max(80).brand("OrderId"),
  date,
  z.string().trim().min(1).max(120),
  z.preprocess(numericCell, z.number().int().min(1).max(10_000)),
  money, money, money, money,
  z.enum(["완료", "취소"]),
]);

export type Order = {
  readonly id: z.infer<typeof rowSchema>[0];
  readonly date: string;
  readonly product: string;
  readonly quantity: number;
  readonly unitPrice: z.infer<typeof money>;
  readonly discount: z.infer<typeof money>;
  readonly shipping: z.infer<typeof money>;
  readonly fee: z.infer<typeof money>;
  readonly status: "완료" | "취소";
  readonly source: string;
  readonly row: number;
};
export type Issue = {
  readonly file: string;
  readonly row: number;
  readonly code: string;
  readonly message: string;
};
export type Summary = {
  readonly orderCount: number;
  readonly completedCount: number;
  readonly canceledCount: number;
  readonly gross: number;
  readonly discount: number;
  readonly shipping: number;
  readonly fee: number;
  readonly expected: number;
};
export type Settlement =
  | { readonly kind: "valid"; readonly orders: readonly Order[]; readonly summary: Summary }
  | { readonly kind: "invalid"; readonly issues: readonly Issue[] };
export type SourceRows = {
  readonly file: string;
  readonly rows: readonly (readonly unknown[])[];
};

export function summarize(orders: readonly Order[]): Summary {
  const completed = orders.filter((order) => order.status === "완료");
  const gross = completed.reduce((sum, order) => sum + order.quantity * order.unitPrice, 0);
  const discount = completed.reduce((sum, order) => sum + order.discount, 0);
  const shipping = completed.reduce((sum, order) => sum + order.shipping, 0);
  const fee = completed.reduce((sum, order) => sum + order.fee, 0);
  return {
    orderCount: orders.length,
    completedCount: completed.length,
    canceledCount: orders.length - completed.length,
    gross, discount, shipping, fee,
    expected: gross - discount + shipping - fee,
  };
}

export function parseOrders(sources: readonly SourceRows[]): Settlement {
  // Accumulators retain row provenance for actionable, batch-blocking errors.
  const issues: Issue[] = [];
  const orders: Order[] = [];
  const seen = new Map<string, Order>();
  let rowCount = 0;
  for (const { file, rows } of sources) {
    const [header, ...body] = rows;
    if (!header || header.length !== HEADERS.length
      || HEADERS.some((name, index) => header[index] !== name)) {
      issues.push({ file, row: 1, code: "HEADER", message: "첫 행의 열 이름과 순서를 샘플 양식에 맞춰 주세요." });
      continue;
    }
    let nonempty = 0;
    for (const [index, cells] of body.entries()) {
      if (cells.every((cell) => cell === null || cell === undefined || cell === "")) continue;
      nonempty += 1;
      rowCount += 1;
      const row = index + 2;
      if (rowCount > MAX_ROWS) {
        return { kind: "invalid", issues: [{ file, row, code: "ROW_LIMIT", message: "한 번에 합계 10,000행까지 처리할 수 있습니다." }] };
      }
      const parsed = rowSchema.safeParse(cells);
      if (!parsed.success) {
        const column = parsed.error.issues[0]?.path[0];
        const label = typeof column === "number" ? HEADERS[column] : undefined;
        issues.push({
          file, row, code: "ROW",
          message: `${label ?? "열 수"} 값을 확인해 주세요. 주문번호·날짜는 텍스트, 금액은 0 이상 정수, 상태는 완료/취소만 가능합니다.`,
        });
        continue;
      }
      const [id, orderDate, product, quantity, unitPrice, discount, shipping, fee, status] = parsed.data;
      if (discount > quantity * unitPrice) {
        issues.push({ file, row, code: "DISCOUNT", message: "할인액이 상품 판매액(수량 × 판매단가)을 초과합니다." });
        continue;
      }
      const order: Order = { id, date: orderDate, product, quantity, unitPrice, discount, shipping, fee, status, source: file, row };
      const previous = seen.get(id);
      if (previous) {
        issues.push({
          file, row, code: "DUPLICATE",
          message: `중복 주문번호: ${id} (${previous.source} ${previous.row}행). 한 주문은 한 행으로 합쳐 주세요.`,
        });
        continue;
      }
      seen.set(id, order);
      orders.push(order);
    }
    if (nonempty === 0) issues.push({ file, row: 2, code: "EMPTY", message: "주문 데이터가 없습니다." });
  }
  if (sources.length === 0) {
    issues.push({ file: "", row: 0, code: "EMPTY", message: "주문 파일을 선택해 주세요." });
  }
  if (issues.length > 0) return { kind: "invalid", issues };
  const summary = summarize(orders);
  if (Object.values(summary).some((value) => !Number.isSafeInteger(value))) {
    return { kind: "invalid", issues: [{ file: "", row: 0, code: "TOTAL_LIMIT", message: "합계가 안전하게 계산할 수 있는 정수 범위를 초과합니다. 파일을 나눠 주세요." }] };
  }
  return { kind: "valid", orders, summary };
}
