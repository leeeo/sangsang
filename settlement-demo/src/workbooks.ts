import { read, utils } from "xlsx";
import { parseOrders, type Issue, type Settlement, type SourceRows } from "./settlement";
import { createSampleWorkbook } from "./workbook-export";

export { createReportWorkbook, createSampleWorkbook } from "./workbook-export";

const MAX_FILE_BYTES = 5 * 1024 * 1024;

export async function analyzeFiles(files: readonly File[]): Promise<Settlement> {
  if (files.length === 0 || files.length > 5) {
    return { kind: "invalid", issues: [{ file: "", row: 0, code: "FILE_COUNT", message: "파일을 1개부터 5개까지 선택해 주세요." }] };
  }
  const sources: SourceRows[] = [];
  const issues: Issue[] = [];
  for (const file of files) {
    const extension = file.name.split(".").at(-1)?.toLowerCase();
    if (extension !== "xlsx" && extension !== "csv") {
      issues.push({ file: file.name, row: 0, code: "FILE_TYPE", message: ".xlsx 또는 UTF-8 .csv 파일만 지원합니다." });
      continue;
    }
    if (file.size === 0 || file.size > MAX_FILE_BYTES) {
      issues.push({ file: file.name, row: 0, code: "FILE_SIZE", message: "빈 파일은 사용할 수 없으며 파일당 최대 5 MiB입니다." });
      continue;
    }
    // The third-party file parser is an untrusted-input boundary.
    try {
      const buffer = await file.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      if (extension === "xlsx" && (bytes[0] !== 0x50 || bytes[1] !== 0x4b)) {
        issues.push({ file: file.name, row: 0, code: "FORMAT", message: "정상적인 XLSX 파일이 아닙니다. Excel에서 .xlsx로 다시 저장해 주세요." });
        continue;
      }
      const input = extension === "csv"
        ? new TextDecoder("utf-8", { fatal: true }).decode(buffer)
        : buffer;
      const workbook = read(input, {
        type: extension === "csv" ? "string" : "array",
        raw: true,
        cellFormula: true,
        sheetRows: 10_002,
      });
      const populated = workbook.SheetNames.flatMap((name) => {
        const sheet = workbook.Sheets[name];
        return sheet?.["!ref"] ? [sheet] : [];
      });
      if (populated.length !== 1) {
        issues.push({ file: file.name, row: 0, code: "SHEET_COUNT", message: "데이터가 있는 시트가 정확히 1개인 파일을 사용해 주세요." });
        continue;
      }
      const sheet = populated[0];
      if (!sheet) continue;
      const reference: string = sheet["!fullref"] ?? sheet["!ref"] ?? "A1";
      const range = utils.decode_range(reference);
      if (range.e.r > 10_000 || range.e.c > 8) {
        issues.push({ file: file.name, row: 0, code: "SHEET_LIMIT", message: "파일은 머리글 포함 10,001행과 표준 양식의 9열 이내여야 합니다. 불필요한 서식·열도 지워 주세요." });
        continue;
      }
      let formulaFound = false;
      for (const [address, cell] of Object.entries(sheet)) {
        if (address.startsWith("!")) continue;
        if (cell.f !== undefined || cell.t === "e") {
          formulaFound = true;
          issues.push({ file: file.name, row: utils.decode_cell(address).r + 1, code: "FORMULA", message: `${address}: 수식이나 오류 셀 대신 값만 붙여넣어 주세요.` });
          break;
        }
      }
      if (formulaFound) continue;
      const rows = utils.sheet_to_json<unknown[]>(sheet, { header: 1, raw: true, defval: null, blankrows: true, range: 0 });
      sources.push({ file: file.name, rows });
    } catch (error) {
      if (!(error instanceof Error)) throw error;
      issues.push({ file: file.name, row: 0, code: "READ", message: "파일을 읽지 못했습니다. 암호를 해제하고 XLSX 또는 UTF-8 CSV로 다시 저장해 주세요." });
    }
  }
  if (issues.length > 0) return { kind: "invalid", issues };
  return parseOrders(sources);
}

export async function analyzeSample(): Promise<Settlement> {
  return analyzeFiles([new File([createSampleWorkbook()], "가상 주문 샘플.xlsx")]);
}

