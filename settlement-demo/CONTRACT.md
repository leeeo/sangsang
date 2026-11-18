# Seller settlement pilot

## Scope

Korean small sellers who manually combine order spreadsheets are a **customer hypothesis**, not validated customers. Build one browser-only demonstration before any hosting, domain purchase, payment setup, or outreach. Never imply marketplace-specific support or tax/accounting accuracy.

The proposed paid pilot is KRW 150,000 for one agreed input format, one settlement workbook output, one revision, and a three-business-day delivery target after sample review and scope agreement. This is an untested offer, not a published price or sales claim.

## Input contract

- Files: `.xlsx` or UTF-8 `.csv`; at most 5 files, 5 MiB each, and 10,000 data rows in total.
- One nonempty worksheet per workbook. Header must be the first row, in this exact order:
  `주문번호,주문일,상품명,수량,판매단가,할인액,배송비,수수료,상태`
- One row represents one complete order, not an order line. Order numbers must be unique across all files. Multi-item orders need a separately agreed adapter.
- Order numbers and dates are text. Date is a valid `YYYY-MM-DD` between 2000 and 2100.
- Quantity is a positive integer. All money fields are nonnegative whole KRW. Discount cannot exceed quantity times unit price. No automatic fee-rate assumptions.
- Status is `완료` or `취소`. Canceled orders are visible but excluded from totals. Partial refunds, tax, purchase costs, and actual payment reconciliation are outside scope.
- Expected settlement = quantity × unit price − discount + shipping − fee, for completed orders only. This is not profit or a guaranteed deposit.
- Reject input formulas and spreadsheet error cells. Do not silently use cached formula values.
- Any invalid row, unsupported format, duplicate, empty file, or exceeded limit blocks exporting the entire batch. Show filename, row, and actionable issue; never silently drop financial data.

## Core API (owned by parent)

`src/settlement.ts` exports:

```ts
type Issue = {
  readonly file: string;
  readonly row: number;
  readonly code: string;
  readonly message: string;
};
type Order = {
  readonly id: string;
  readonly date: string;
  readonly product: string;
  readonly quantity: number;
  readonly unitPrice: number;
  readonly discount: number;
  readonly shipping: number;
  readonly fee: number;
  readonly status: "완료" | "취소";
  readonly source: string;
  readonly row: number;
};
type Summary = {
  readonly orderCount: number;
  readonly completedCount: number;
  readonly canceledCount: number;
  readonly gross: number;
  readonly discount: number;
  readonly shipping: number;
  readonly fee: number;
  readonly expected: number;
};
type Settlement =
  | { readonly kind: "valid"; readonly orders: readonly Order[]; readonly summary: Summary }
  | { readonly kind: "invalid"; readonly issues: readonly Issue[] };
```

`src/workbooks.ts` exports:

```ts
// Browser input; replacement, not append. No network or persistence.
analyzeFiles(files: readonly File[]): Promise<Settlement>;
// Uses the exact same file parsing path as an uploaded file.
analyzeSample(): Promise<Settlement>;
// Return actual XLSX bytes for a browser Blob/download.
createSampleWorkbook(): Uint8Array;
createReportWorkbook(result: Extract<Settlement, { kind: "valid" }>): Uint8Array;
```

UI must narrow `Settlement.kind` before exporting. Parent will implement the core modules and tests; UI worker must not edit them.

## UI worker ownership

Own `package.json`, lockfile, tsconfig, Vite setup, index.html, `src/main.ts`, UI-only modules, CSS, `DESIGN.md`, and design evidence. Use vanilla TypeScript + Vite; no React needed for this single surface.

Dependencies required by core: `zod` v4 and `xlsx` from `https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz`. Tests use `bun:test` and `@types/bun`.

Scripts: `dev` bound to `127.0.0.1:8796` with strictPort, `build` = typecheck + Vite build, `test` = `bun test`, `preview` bound to `127.0.0.1:8796` with strictPort. Ensure no stale result can be exported during/after a failed new upload. Use a file input with multiple selection and accept extensions; sample action, template download, clear/reset, errors and genuine report download must work. Limit rendered previews, not calculation. Include local-only data handling notice, prototype/sample labeling, explicit limits and calculation scope, fixed-scope pilot information without fake contact/payment buttons.

The UI should be polished, readable Korean at desktop and 390px mobile, keyboard accessible, and honest about the unsupported cases. No marketing metrics, fake testimonials, invented customers, or invented contact information.

## Delivery boundaries

- Work only in this directory inside the dedicated worktree.
- No commits, push, external publishing, contact messages, or infrastructure changes.
- Existing Android work is preserved.
- Browser automation uses the visible wmux browser per workspace policy.
