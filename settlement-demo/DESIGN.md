# 정산 한 장 Design System

Working name only. No domain, no hosting, no marketing metrics. One surface: a
browser-only settlement prototype for Korean small sellers (see CONTRACT.md).

## 0. Research Log (greenfield)

- Embedded refs: shortlisted `mastercard.md` (warm cream canvas, editorial
  fintech warmth), `wise.md` (bold lime fintech), `notion.md` (warm minimal
  workspace) -> picked Layer A `taste-skill.md` (operational brief, restraint,
  anti-tell discipline; it declares data-table product UI out of its own scope,
  so only its typography, color-lock, form, state and copy rules are applied) +
  Layer B `mastercard.md` because a settlement "sheet" reads best as paper on a
  warm desk: putty cream canvas, warm ink, one signal color reserved for
  blocking issues, oversized radii, weight-450 body, one-font system.
- Lazyweb: 2 queries ("spreadsheet upload import validation errors",
  "payout settlement summary report finance"), 5 screens downloaded, 3 viewed
  (Okta CSV import error modal, Monarch Money cash-flow report, Airbnb payout
  transaction history). Grammar taken: issue list sits directly above the file
  control and blocks the next step; stat tiles carry one large figure with a
  small caption under it; a summary aside sits beside the transaction list;
  empty state is a quiet bordered panel with a one-line explanation. No pixels
  copied; screenshots are not stored in the repo.
- StyleGallery: fetched CATALOG.md, `patterns/split-sidebar/supporting-pane.md`
  and `patterns/split-sidebar/sticky-aside.md`. Adopted: supporting-pane
  (primary task left, summary aside right, auto-fit reflow to one column at
  narrow widths) with the sticky-aside offset for the summary sheet on
  desktop. Scroll owner: the document; no internal scroll containers except the
  preview table's horizontal overflow wrapper.
- Imagen drafts: skipped. No image-generation tool exists in this session.
- ui-ux-db: skipped. The CLI needs `uv`/python with the ruleset data; the
  palette and type pairing come straight from the Layer B reference instead.

## 1. Atmosphere & Identity

The hero keeps its two Korean clauses in separate block spans, so desktop
line wrapping cannot separate "정산" from "한 장으로".

A single settlement sheet laid on a warm desk. The page is quiet putty cream;
the only bright object is the lifted, softly haloed sheet that holds the
expected settlement figure. Everything else (upload, issues, preview, scope,
pilot) is ink on cream with generous whitespace. The signature is the paper
sheet: 40px stadium corners, weight-500 headline numbers with tabular figures,
and a single rust signal color that appears only when something blocks export.
Honesty is part of the look: limits and exclusions are typeset as real content,
not fine print.

Design read: operations tool for Korean small sellers, trust-first, local-only.
Dials: DESIGN_VARIANCE 4, MOTION_INTENSITY 3, VISUAL_DENSITY 5.

## 2. Color

Light theme only (a print-like sheet; the page theme is locked, no section
inverts). Every value below is a CSS custom property in `src/styles/tokens.css`.

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Canvas | `--surface-canvas` | #F3F0EE | Page background (Mastercard canvas cream) |
| Lifted | `--surface-lifted` | #FCFBFA | Sheet, cards, table body |
| White | `--surface-white` | #FFFFFF | Nav pill, secondary button fill, inputs |
| Bone | `--surface-bone` | #F4F4F4 | Table header band, code samples |
| Ink | `--ink` | #141413 | Headlines, body, primary button fill |
| Ink wash 8 | `--ink-a08` | rgb(20 19 19 / .08) | Hover wash, hairlines on lifted |
| Ink wash 16 | `--ink-a16` | rgb(20 19 19 / .16) | Pressed wash, input border |
| Ink wash 40 | `--ink-a40` | rgb(20 19 19 / .40) | Disabled text on cream |
| Slate | `--text-muted` | #696969 | Captions, secondary text |
| Taupe | `--line-soft` | #D1CDC7 | Table row hairlines, dividers |
| Signal | `--signal` | #CF4500 | Blocking issues text/icon, error focus |
| Signal wash | `--signal-a10` | rgb(207 69 0 / .10) | Issue panel background |
| Link | `--link` | #3860BE | Inline links, info notice glyph |
| Cream on ink | `--on-ink` | #F3F0EE | Text on primary button and footer |

### Rules
- Ink is the one accent for actions: the primary button is an ink pill, the
  secondary is an outlined pill. Nothing decorative carries color.
- Signal is reserved for blocking states (invalid batch). It never marks a CTA.
- Success is not a color: a validated result is shown by the sheet filling with
  figures and a check glyph in an ink chip.
- Canceled orders are muted slate, never struck through or red.

## 3. Typography

One family: `Pretendard Variable` (SIL OFL, self-hosted from the `pretendard`
npm package, dynamic unicode-range subsets, `font-display: swap`). Fallbacks:
`"Apple SD Gothic Neo", "Malgun Gothic", system-ui, sans-serif`. No serif, no
second display face; numbers use `font-variant-numeric: tabular-nums`.

| Level | Token | Size | Weight | Line height | Tracking | Usage |
|-------|-------|------|--------|-------------|----------|-------|
| Display | `--type-display` | clamp(2.25rem, 1.5rem + 3vw, 3.5rem) | 500 | 1.12 | -0.02em | Hero headline |
| Figure | `--type-figure` | clamp(2rem, 1.25rem + 2.5vw, 3rem) | 500 | 1.05 | -0.02em | Expected settlement |
| H2 | `--type-h2` | 1.75rem | 500 | 1.25 | -0.015em | Section titles |
| H3 | `--type-h3` | 1.25rem | 500 | 1.35 | -0.01em | Sheet title, card titles |
| Stat | `--type-stat` | 1.375rem | 500 | 1.2 | -0.01em | Stat tile numbers |
| Body | `--type-body` | 1rem | 450 | 1.6 | 0 | Default text |
| Body sm | `--type-sm` | 0.875rem | 450 | 1.55 | 0 | Table cells, helper text |
| Caption | `--type-caption` | 0.75rem | 500 | 1.4 | 0.01em | Stat captions, meta |
| Eyebrow | `--type-eyebrow` | 0.8125rem | 700 | 1 | 0.04em | Two eyebrows max on the page |

Rules: body never below 14px; Korean headlines wrap at most 2 lines at 1280px;
no uppercase transforms (Korean has none; Latin eyebrow text stays sentence case
with tracking only).

## 4. Spacing & Layout

Base unit 4px; the Mastercard 8-multiple rhythm sits on top of it.

| Token | Value | Usage |
|-------|-------|-------|
| `--space-1` | 4px | Icon to label |
| `--space-2` | 8px | Inline groups, chip padding |
| `--space-3` | 12px | Input padding, table cell padding |
| `--space-4` | 16px | Card padding (mobile), list gaps |
| `--space-5` | 20px | Button horizontal padding |
| `--space-6` | 24px | Card padding (desktop), section inner gap |
| `--space-8` | 32px | Between blocks inside a section |
| `--space-10` | 40px | Sheet padding (desktop) |
| `--space-12` | 48px | Section gap (mobile) |
| `--space-16` | 64px | Section gap (tablet) |
| `--space-24` | 96px | Section gap (desktop) |

Control heights: `--control-height` 44px, `--control-height-sm` 36px,
`--chip-height` 28px. Line weights: `--border-control` 1.5px (buttons,
picker dash, canvas card), `--hairline` 1px (table rows, footer divider).

Grid: max content width 1200px; page gutter `clamp(16px, 4vw, 48px)`.
Work area = supporting-pane grid `minmax(0, 1fr) minmax(min(20rem, 100%), 22rem)`
at >= 1024px, single column below. Breakpoints: sm 640, md 768, lg 1024.
Nav: one line, 64px tall pill floating 16px below the top.

## 5. Components

### Button
- Structure: `<button class="btn btn--primary|btn--secondary" type="button">`
  optional leading SVG glyph (inline, 16px, currentColor).
- Variants: primary (ink fill, cream text), secondary (white fill, 1.5px ink
  border). Sizes: default 44px tall, small 36px (table toolbar only).
- Spacing: padding 0 `--space-5`; gap `--space-2` between glyph and label.
- States: hover = ink wash overlay (primary: lifted 4% white; secondary:
  `--ink-a08` fill); active = `scale(.98)`; focus-visible = 2px ring `--ink`
  offset 2px (on signal contexts the ring is `--signal`); disabled = 40%
  opacity, `cursor: not-allowed`, `aria-disabled` mirrored by `disabled`;
  busy = disabled plus label swap to progress text, `aria-busy` on the region.
- Accessibility: native button, label always text (glyph `aria-hidden`).
- Motion: color/opacity 150ms ease-out; transform 120ms ease-out.
- Layout: inline cluster (`.cluster`) that wraps.

### FilePicker
- Structure: `<div class="picker">` containing a visually rich `<label>` bound
  to `<input type="file" multiple accept=".xlsx,.csv">`, helper line, and a
  file list `<ul class="picker__files">`.
- Variants: idle, has-files.
- Spacing: padding `--space-8` desktop / `--space-6` mobile; dashed 1.5px
  `--ink-a16` inner border on lifted cream; 40px radius (sheet family).
- States: hover = `--ink-a08` wash; drag-over = wash + solid border;
  focus-within = 2px ring (the input keeps native focus, visible via
  `:focus-visible` on the wrapper); disabled while busy (input disabled,
  wrapper `aria-disabled`); error = the IssueList renders directly above it and
  the picker gets `aria-describedby` pointing at the issue heading.
- Accessibility: label text is the instruction; the input is not hidden from
  AT (visually clipped, not `display:none`); drop works via the input too.
- Motion: none beyond the state washes.
- Layout: stack.

### Chip
- Structure: `<span class="chip chip--ink|chip--muted|chip--signal">` glyph + text.
- Spacing: padding `--space-1` `--space-3`; pill radius; caption type.
- States: static, no hover.
- Usage: local-only notice in nav, "가상 샘플" tag, order status in preview.

### StatTile
- Structure: `<div class="stat"><span class="stat__value">…</span>
  <span class="stat__label">…</span></div>`; value uses Stat type + tabular nums.
- Spacing: padding `--space-3`; two equal columns with zero minimum track
  width. Real browser QA found auto-fit collapsing the narrow desktop aside
  into seven tall rows, unnecessarily burying export. Long figures wrap.
- States: empty (value shows `-`, label unchanged); loaded.
- Layout: deconstructed-pancake grid inside the sheet.

### SummarySheet
- Structure: `<aside class="sheet" aria-labelledby="sheet-title">` with title,
  status chip, Figure (expected settlement), StatTile grid, formula line,
  disclaimer, and the export Button.
- Variants: empty (no result: figure `-`, export disabled, hint text), busy
  (all disabled, live text "계산 중"), invalid (figure `-`, export disabled,
  short line "차단된 문제 N건" pointing to the IssueList), valid (figures,
  export enabled).
- Spacing: padding `--space-10` desktop / `--space-6` mobile; 40px radius;
  Level 1 halo; sticky at `top: 96px` on lg.
- States: as variants; the figure region is `aria-live="polite"`.
- Accessibility: figure has a visually hidden "원" unit repeated in text; the
  export button explains why it is disabled via `aria-describedby`.
- Motion: on new valid result the figure fades/rises 300ms; reduced motion =
  fade only.

### IssueList
- Structure: `<section class="issues" role="alert" aria-labelledby>`: H3 with
  count, `<ol>` rows: file (bold), row number (tabular), message.
- Spacing: padding `--space-6`; radius 20px; background `--signal-a10`;
  glyph in `--signal`; text stays ink for contrast.
- States: rendered only when the result is invalid; capped to 200 rows with a
  count line "그 외 N건".
- Accessibility: focus moves to the heading after an invalid run.
- Layout: stack; no per-row borders, rows separated by `--space-3` gaps.

### PreviewTable
- Structure: `<div class="table-wrap" tabindex="0" role="region"
  aria-label>` around `<table>`; `<caption>` names the shown/total rows.
- Spacing: cell padding `--space-3`; header band on `--surface-bone`; single
  hairline `--line-soft` under rows; numeric columns right aligned, tabular.
- States: empty (not rendered; the empty-state Notice shows instead); loaded
  (first 50 orders, caption says how many are hidden; calculation is never
  limited).
- Accessibility: `th scope`, region is keyboard scrollable, horizontal scroll
  only inside the wrapper.
- Order IDs and ISO dates stay on one line. Product names and source filenames get at least 12rem
  so normal Korean names do not split into single-syllable fragments.

### Notice
- Structure: `<p class="notice notice--info|notice--muted">` glyph + text.
- Usage: local-only processing, sample labeling, limits, empty state.
- Spacing: padding `--space-4`; radius 20px; lifted cream; no border.

### SectionHeader
- Structure: `<header class="section__head">` optional eyebrow (dot + text,
  max two on the page: hero and pilot) + H2 + one paragraph (max 65ch).
- Layout: vertical stack, left aligned; never split-header.

## 6. Motion & Interaction

| Type | Duration | Easing | Usage |
|------|----------|--------|-------|
| Micro | 120-150ms | ease-out | Button press, washes |
| Standard | 250-300ms | cubic-bezier(.16,1,.3,1) | Result panel entry |

Feedback: any async action disables every control at once and clears the
previous result before work starts; a status line in the sheet reads "계산
중"; failures are reported in place (IssueList) and success is the sheet
itself. Only `transform` and `opacity` animate. `prefers-reduced-motion`:
translations become plain fades.

## 7. Depth & Surface

Strategy: tonal (canvas -> lifted -> white) plus one halo level; hairlines only
inside tables and as the picker's dashed edge.

| Level | Value | Usage |
|-------|-------|-------|
| 0 | none | Default |
| 1 | `0 24px 48px rgb(20 19 19 / .08)` | SummarySheet, nav pill (nav uses `0 4px 24px rgb(20 19 19 / .04)`) |

| Radius | Token | Usage |
|--------|-------|-------|
| 20px | `--radius-md` | Buttons, inputs, notices, issue panel, stat tiles |
| 40px | `--radius-lg` | SummarySheet, FilePicker, pilot card |
| 9999px | `--radius-full` | Nav pill, chips |

Nested corners are concentric: stat tiles (20px) sit inside the sheet (40px)
with 20px+ of padding between them.

## 8. Accessibility Constraints & Accepted Debt

Constraints: WCAG 2.2 AA. Body contrast: ink on cream 15.5:1, slate on cream
5.3:1, signal on cream 5.0:1 (used only for glyph and heading, body of issues
stays ink). Every control keyboard reachable in DOM order; visible
focus-visible ring on every control; the file input remains a real input;
`aria-live` for result status; `role="alert"` for the issue panel; the preview
region is focusable for keyboard scrolling; touch targets >= 44px; Korean
`lang="ko"`; reduced motion honored.

| Item | Location | Why accepted | Owner / Exit |
|------|----------|--------------|--------------|
| Preview limited to 50 rendered rows | PreviewTable | Contract asks to limit rendering only; full data is in the export | Revisit if pilot users ask for in-page paging |
| Light theme only | whole page | Print-like sheet identity; brief is a single operations surface | Add dark tokens if a real product follows |
| No drag-and-drop highlight on Safari iOS | FilePicker | Native file input is the primary path on mobile | none |
