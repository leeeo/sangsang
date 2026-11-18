import { describe, expect, test } from "bun:test";
import { read, utils, write, type WorkBook } from "xlsx";
import { HEADERS } from "../src/settlement";
import { analyzeFiles, analyzeSample, createReportWorkbook, createSampleWorkbook } from "../src/workbooks";

const row = ["0001", "2026-09-01", "테스트 상품", 2, 12000, 2000, 3000, 1200, "완료"] as const;

function workbookFile(book: WorkBook, name = "input.xlsx"): File {
  const buffer: unknown = write(book, { type: "array", bookType: "xlsx" });
  if (!(buffer instanceof ArrayBuffer)) throw new TypeError("Unexpected XLSX output");
  return new File([buffer], name);
}

function workbook(): WorkBook {
  const book = utils.book_new();
  utils.book_append_sheet(book, utils.aoa_to_sheet([[...HEADERS], [...row]]), "주문");
  return book;
}

describe("real spreadsheet boundary", () => {
  test("runs synthetic data through the actual XLSX upload path", async () => {
    // Given: the app sample uses generated XLSX, not bypassed JSON.
    // When
    const result = await analyzeSample();
    // Then
    expect(result).toMatchObject({
      kind: "valid",
      summary: { orderCount: 6, completedCount: 5, canceledCount: 1, gross: 152000, discount: 7000, shipping: 12000, fee: 7600, expected: 149400 },
    });
  });

  test("parses UTF-8 BOM CSV with quoted commas", async () => {
    // Given
    const csv = `\uFEFF${HEADERS.join(",")}\r\n0001,2026-09-01,"상품, 대형",2,"12,000",2000,3000,1200,완료`;
    // When
    const result = await analyzeFiles([new File([csv], "orders.csv")]);
    // Then
    expect(result).toMatchObject({ kind: "valid", orders: [{ id: "0001", product: "상품, 대형" }], summary: { expected: 23800 } });
  });

  test("merges unique orders from multiple real workbooks", async () => {
    // Given
    const second = utils.book_new();
    utils.book_append_sheet(second, utils.aoa_to_sheet([[...HEADERS], ["0002", ...row.slice(1)]]), "주문");
    // When
    const result = await analyzeFiles([workbookFile(workbook(), "a.xlsx"), workbookFile(second, "b.xlsx")]);
    // Then
    expect(result).toMatchObject({ kind: "valid", summary: { orderCount: 2, expected: 47600 } });
  });

  test("blocks cached formula inputs rather than trusting stale values", async () => {
    // Given
    const book = workbook();
    const sheet = book.Sheets["주문"];
    if (!sheet) throw new TypeError("Missing fixture sheet");
    sheet["E2"] = { t: "n", f: "99999+1", v: 12000 };
    // When
    const result = await analyzeFiles([workbookFile(book)]);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "FORMULA", row: 2 }] });
  });

  test("rejects multiple populated sheets instead of silently dropping one", async () => {
    // Given
    const book = workbook();
    utils.book_append_sheet(book, utils.aoa_to_sheet([[...HEADERS], [...row]]), "다른 주문");
    // When
    const result = await analyzeFiles([workbookFile(book)]);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "SHEET_COUNT" }] });
  });

  test("blocks the entire batch when one file cannot be decoded", async () => {
    // Given
    const good = new File([createSampleWorkbook()], "good.xlsx");
    const bad = new File([new Uint8Array([0xff, 0xfe, 0xfa])], "bad.csv");
    // When
    const result = await analyzeFiles([good, bad]);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "READ", file: "bad.csv" }] });
    expect("orders" in result).toBe(false);
  });

  test.each([
    [new File(["not a workbook"], "fake.xlsx"), "FORMAT"],
    [new File(["text"], "old.xls"), "FILE_TYPE"],
    [new File([], "empty.csv"), "FILE_SIZE"],
    [new File([new Uint8Array(5 * 1024 * 1024 + 1)], "big.xlsx"), "FILE_SIZE"],
  ])("blocks unsupported file %s", async (file, code) => {
    // Given
    if (!(file instanceof File)) throw new TypeError("Invalid fixture");
    // When
    const result = await analyzeFiles([file]);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code }] });
  });

  test("caps file count before reading any files", async () => {
    // Given
    const files = Array.from({ length: 6 }, () => new File(["x"], "input.csv"));
    // When
    const result = await analyzeFiles(files);
    // Then
    expect(result).toMatchObject({ kind: "invalid", issues: [{ code: "FILE_COUNT" }] });
  });

  test("exports summary, traceable detail and recalculable formulas with cached values", async () => {
    // Given
    const input = await analyzeSample();
    if (input.kind !== "valid") throw new TypeError("Invalid sample");
    // When
    const exported = read(createReportWorkbook(input), { cellFormula: true });
    // Then: independently known fixture totals and actual XLSX formula cells.
    expect(exported.SheetNames).toEqual(["정산요약", "정산내역", "사용안내"]);
    expect(exported.Sheets["정산요약"]?.["B9"]).toMatchObject({ t: "n", v: 149400, f: "SUM('정산내역'!K2:K7)" });
    expect(exported.Sheets["정산내역"]?.["J2"]).toMatchObject({ v: 24000, f: "D2*E2" });
    expect(exported.Sheets["정산내역"]?.["K2"]).toMatchObject({ v: 23800, f: 'IF(I2="완료",J2-F2+G2-H2,0)' });
    expect(exported.Sheets["정산내역"]?.["K4"]).toMatchObject({ v: 0 });
    expect(exported.Sheets["정산내역"]?.["L2"]?.v).toBe("가상 주문 샘플.xlsx");
  });

  test("exports formula-looking user text as inert string cells", async () => {
    // Given
    const csv = `${HEADERS.join(",")}\n0001,2026-09-01,=1+1,1,1000,0,0,0,완료`;
    const parsed = await analyzeFiles([new File([csv], "text.csv")]);
    if (parsed.kind !== "valid") throw new TypeError("Invalid fixture");
    // When
    const exported = read(createReportWorkbook(parsed));
    // Then
    expect(exported.Sheets["정산내역"]?.["C2"]).toMatchObject({ t: "s", v: "=1+1" });
    expect(exported.Sheets["정산내역"]?.["C2"]?.f).toBeUndefined();
  });
});
