import { describe, expect, test } from "bun:test";
import { HEADERS, parseOrders } from "../src/settlement";

const order = ["0001", "2026-09-01", "테스트 상품", 2, 12000, 2000, 3000, 1200, "완료"] as const;
const source = (rows: readonly (readonly unknown[])[]) => [{ file: "orders.xlsx", rows: [[...HEADERS], ...rows] }];

describe("order settlement", () => {
  test("calculates completed orders and excludes canceled money", () => {
    // Given: one completed and one canceled order with monetary values.
    const files = source([order, ["0002", "2026-09-02", "취소 상품", 5, 10000, 1000, 3000, 2000, "취소"]]);
    // When
    const result = parseOrders(files);
    // Then
    expect(result.kind).toBe("valid");
    if (result.kind !== "valid") throw new TypeError("Expected a valid fixture");
    expect(result.summary).toEqual({
      orderCount: 2, completedCount: 1, canceledCount: 1,
      gross: 24000, discount: 2000, shipping: 3000, fee: 1200, expected: 23800,
    });
  });

  test("preserves leading zero IDs and accepts grouped whole KRW strings", () => {
    // Given
    const row = ["0001", "2026-09-01", "상품", "2", "12,000", "2,000", "3,000", "1,200", "완료"];
    // When
    const result = parseOrders(source([row]));
    // Then
    expect(result.kind).toBe("valid");
    if (result.kind !== "valid") throw new TypeError("Expected a valid fixture");
    expect(String(result.orders[0]?.id)).toBe("0001");
    expect(result.summary.expected).toBe(23800);
  });

  test.each([
    [0, 1234567890123456, "ROW"],
    [1, "2026-02-30", "ROW"],
    [1, 46200, "ROW"],
    [2, "", "ROW"],
    [3, 0, "ROW"],
    [3, 1.5, "ROW"],
    [4, -1, "ROW"],
    [4, "1,2,000", "ROW"],
    [4, "1e3", "ROW"],
    [5, "", "ROW"],
    [5, 24001, "DISCOUNT"],
    [6, Number.NaN, "ROW"],
    [7, 1.5, "ROW"],
    [8, "부분환불", "ROW"],
  ])("blocks the whole batch for invalid cell %s=%s", (column, value, code) => {
    // Given
    if (typeof column !== "number") throw new TypeError("Invalid case");
    const changed: unknown[] = [...order];
    changed[column] = value;
    // When
    const result = parseOrders(source([changed]));
    // Then
    expect(result.kind).toBe("invalid");
    if (result.kind !== "invalid") throw new TypeError("Expected rejection");
    expect(result.issues[0]?.code).toBe(code);
    expect(result.issues[0]?.row).toBe(2);
    expect("summary" in result).toBe(false);
  });

  test("rejects duplicate orders across files with the first source location", () => {
    // Given
    const files = [
      { file: "first.xlsx", rows: [[...HEADERS], [...order]] },
      { file: "second.xlsx", rows: [[...HEADERS], [...order]] },
    ];
    // When
    const result = parseOrders(files);
    // Then
    expect(result.kind).toBe("invalid");
    if (result.kind !== "invalid") throw new TypeError("Expected rejection");
    expect(result.issues[0]).toMatchObject({ code: "DUPLICATE", file: "second.xlsx", row: 2 });
  });

  test("rejects reordered headers rather than shifting money silently", () => {
    // Given
    const header: string[] = [...HEADERS];
    [header[4], header[5]] = ["할인액", "판매단가"];
    // When
    const result = parseOrders([{ file: "wrong.csv", rows: [header, [...order]] }]);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "HEADER", row: 1 }] });
  });

  test("rejects header-only and missing batches", () => {
    // Given
    const files = source([]);
    // When
    const result = parseOrders(files);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "EMPTY" }] });
  });

  test("retains original row numbers across blank rows", () => {
    // Given
    const files = source([[], ["bad"]]);
    // When
    const result = parseOrders(files);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ row: 3 }] });
  });

  test("caps combined data rows across otherwise valid input", () => {
    // Given
    const rows = Array.from({ length: 10_001 }, (_, index) => [String(index), ...order.slice(1)]);
    // When
    const result = parseOrders(source(rows));
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "ROW_LIMIT" }] });
  });

  test("rejects totals outside safe integer precision", () => {
    // Given
    const rows = Array.from({ length: 1000 }, (_, index) => [
      String(index), "2026-09-01", "고액 상품", 10000, 1_000_000_000, 0, 0, 0, "완료",
    ]);
    // When
    const result = parseOrders(source(rows));
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "TOTAL_LIMIT" }] });
  });

  test("returns zero amounts when every order is canceled", () => {
    // Given
    const canceled = [...order.slice(0, 8), "취소"];
    // When
    const result = parseOrders(source([canceled]));
    // Then
    expect(result).toMatchObject({ kind: "valid", summary: { completedCount: 0, canceledCount: 1, expected: 0 } });
  });
});
