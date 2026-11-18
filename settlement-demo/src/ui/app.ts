import type { Issue, Settlement } from "../settlement";
import { h, replace } from "./dom";
import { downloadXlsx } from "./download";
import { formatBytes, formatCount, formatKrw, todayStamp } from "./format";
import { icon } from "./icons";
import { statTile, type PageRefs } from "./page";
import { emptyNotice, issueList, previewTable } from "./results";

type ValidSettlement = Extract<Settlement, { kind: "valid" }>;

/** What a run was started from. Drives the status label, the source caption and the sample flag. */
type RunOrigin = { readonly kind: "files"; readonly files: readonly File[] } | { readonly kind: "sample" };

type Phase =
  | { readonly kind: "idle" }
  | { readonly kind: "busy"; readonly origin: RunOrigin }
  | { readonly kind: "valid"; readonly result: ValidSettlement; readonly origin: RunOrigin }
  | { readonly kind: "invalid"; readonly issues: readonly Issue[]; readonly origin: RunOrigin };

const STAT_LABELS = ["전체 주문", "완료 주문", "취소 주문 (제외)", "상품 판매액", "할인액", "배송비", "수수료"] as const;

function describe(origin: RunOrigin): string {
  if (origin.kind === "sample") return "가상 주문 샘플";
  const [first] = origin.files;
  return origin.files.length === 1 && first ? first.name : `파일 ${origin.files.length}개`;
}

function busyLabel(origin: RunOrigin): string {
  return origin.kind === "sample" ? "가상 샘플 계산 중" : "주문 파일 검증과 계산 중";
}

function toError(value: unknown): Error {
  return value instanceof Error ? value : new Error(String(value));
}

export function mountApp(refs: PageRefs): void {
  // SheetJS-backed core is split into its own chunk and preloaded right after the UI paints.
  const core = import("../workbooks");
  let phase: Phase = { kind: "idle" };
  let selected: readonly File[] = [];
  let run = 0;

  function setPhase(next: Phase): void {
    phase = next;
    render();
  }

  function selectFiles(files: readonly File[]): void {
    selected = files;
    // Any change to the input invalidates whatever was computed before.
    run += 1;
    setPhase({ kind: "idle" });
  }

  async function execute(origin: RunOrigin): Promise<void> {
    run += 1;
    const id = run;
    setPhase({ kind: "busy", origin });
    let settlement: Settlement;
    try {
      const module = await core;
      settlement = origin.kind === "sample" ? await module.analyzeSample() : await module.analyzeFiles(origin.files);
    } catch (thrown) {
      const error = toError(thrown);
      console.error(`settlement run failed: ${error.name}: ${error.message}`);
      settlement = {
        kind: "invalid",
        issues: [{ file: describe(origin), row: 0, code: "UNEXPECTED", message: "처리 중 예상하지 못한 오류가 발생했습니다. 파일을 다시 저장한 뒤 시도해 주세요." }],
      };
    }
    if (id !== run) return;
    switch (settlement.kind) {
      case "valid":
        setPhase({ kind: "valid", result: settlement, origin });
        return;
      case "invalid":
        setPhase({ kind: "invalid", issues: settlement.issues, origin });
        refs.result.querySelector<HTMLElement>("#issues-title")?.focus();
        return;
      default:
        settlement satisfies never;
    }
  }

  refs.input.addEventListener("change", () => {
    selectFiles(Array.from(refs.input.files ?? []));
  });

  for (const type of ["dragenter", "dragover"] as const) {
    refs.picker.addEventListener(type, (event) => {
      if (phase.kind === "busy") return;
      event.preventDefault();
      refs.picker.classList.add("is-dragover");
    });
  }
  refs.picker.addEventListener("dragleave", (event) => {
    if (event.relatedTarget instanceof Node && refs.picker.contains(event.relatedTarget)) return;
    refs.picker.classList.remove("is-dragover");
  });
  refs.picker.addEventListener("drop", (event) => {
    event.preventDefault();
    refs.picker.classList.remove("is-dragover");
    if (phase.kind === "busy") return;
    const dropped = Array.from(event.dataTransfer?.files ?? []);
    if (dropped.length === 0) return;
    const transfer = new DataTransfer();
    for (const file of dropped) transfer.items.add(file);
    refs.input.files = transfer.files;
    selectFiles(dropped);
  });

  refs.runButton.addEventListener("click", () => {
    void execute({ kind: "files", files: selected });
  });
  refs.sampleButton.addEventListener("click", () => {
    void execute({ kind: "sample" });
  });
  refs.templateButton.addEventListener("click", () => {
    void core.then(({ createSampleWorkbook }) => {
      downloadXlsx(createSampleWorkbook(), "정산-한-장-샘플-양식.xlsx");
    });
  });
  refs.resetButton.addEventListener("click", () => {
    refs.input.value = "";
    selectFiles([]);
    refs.input.focus();
  });
  refs.exportButton.addEventListener("click", () => {
    void core.then(({ createReportWorkbook }) => {
      // Narrow on the live phase after the await: nothing but the current valid result may be exported.
      if (phase.kind !== "valid") return;
      downloadXlsx(createReportWorkbook(phase.result), `정산-한-장-${todayStamp()}.xlsx`);
    });
  });

  function render(): void {
    const busy = phase.kind === "busy";
    refs.picker.setAttribute("aria-disabled", String(busy));
    refs.input.disabled = busy;
    refs.runButton.disabled = busy || selected.length === 0;
    refs.sampleButton.disabled = busy;
    refs.templateButton.disabled = busy;
    refs.resetButton.disabled = busy || (selected.length === 0 && phase.kind === "idle");
    refs.exportButton.disabled = phase.kind !== "valid";
    refs.sheet.setAttribute("aria-busy", String(busy));
    refs.sheet.classList.toggle("is-fresh", phase.kind === "valid");
    replace(
      refs.fileList,
      selected.map((file) =>
        h("li", {}, icon("fileXls"), h("span", {}, file.name), h("span", { className: "picker__size num" }, formatBytes(file.size))),
      ),
    );
    refs.status.textContent = phase.kind === "busy" ? busyLabel(phase.origin) : "";
    renderSheet();
    renderResult();
  }

  function renderSheet(): void {
    if (phase.kind === "valid") {
      const { summary } = phase.result;
      const sample = phase.origin.kind === "sample";
      refs.sheetChip.className = "chip chip--ink";
      replace(refs.sheetChip, [icon("check"), sample ? "검증 완료 · 가상 샘플" : "검증 완료"]);
      refs.figureValue.className = "sheet__figure-value num";
      refs.figureValue.textContent = formatKrw(summary.expected);
      refs.figureSource.textContent = `${describe(phase.origin)} 기준, 완료 주문 ${formatCount(summary.completedCount, "건")} 합산`;
      const values = [
        formatCount(summary.orderCount, "건"),
        formatCount(summary.completedCount, "건"),
        formatCount(summary.canceledCount, "건"),
        formatKrw(summary.gross),
        formatKrw(summary.discount),
        formatKrw(summary.shipping),
        formatKrw(summary.fee),
      ];
      replace(refs.stats, STAT_LABELS.map((label, index) => statTile(label, values[index] ?? "-", false)));
      refs.exportNote.textContent = sample
        ? "가상 샘플 결과입니다. 실제 매출이 아니며 내려받는 파일에도 그렇게 표시됩니다."
        : "요약, 내역, 사용 안내 시트가 든 엑셀 파일을 이 브라우저에서 바로 만듭니다.";
      return;
    }
    refs.figureValue.className = "sheet__figure-value is-empty num";
    refs.figureValue.textContent = "-";
    replace(refs.stats, STAT_LABELS.map((label) => statTile(label, "-", true)));
    if (phase.kind === "busy") {
      refs.sheetChip.className = "chip chip--muted";
      refs.sheetChip.textContent = "계산 중";
      refs.figureSource.textContent = "이전 결과는 지웠습니다. 계산이 끝나면 여기에 표시됩니다.";
      refs.exportNote.textContent = "계산이 끝날 때까지 다운로드는 잠깁니다.";
      return;
    }
    if (phase.kind === "invalid") {
      refs.sheetChip.className = "chip chip--signal";
      replace(refs.sheetChip, [icon("warningCircle"), "다운로드 차단"]);
      refs.figureSource.textContent = `${describe(phase.origin)}: 문제 ${formatCount(phase.issues.length, "건")}. 모두 고친 뒤 다시 계산해 주세요.`;
      refs.exportNote.textContent = "문제가 하나라도 있으면 묶음 전체를 내려받을 수 없습니다.";
      return;
    }
    refs.sheetChip.className = "chip chip--muted";
    refs.sheetChip.textContent = "대기 중";
    refs.figureSource.textContent = "파일을 올리거나 가상 샘플로 계산하면 표시됩니다.";
    refs.exportNote.textContent = "검증을 통과한 결과만 내려받을 수 있습니다.";
  }

  function renderResult(): void {
    switch (phase.kind) {
      case "valid":
        replace(refs.result, [previewTable(phase.result.orders, phase.origin.kind === "sample")]);
        return;
      case "invalid":
        replace(refs.result, [issueList(phase.issues)]);
        return;
      case "busy":
        replace(refs.result, []);
        return;
      case "idle":
        replace(refs.result, [emptyNotice()]);
        return;
      default:
        phase satisfies never;
    }
  }
}
