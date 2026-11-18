import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { read } from "xlsx";

// The user approved this independent, visible Chrome QA window after the
// shared wmux renderer could not reliably produce fresh screenshots.
const evidence = fileURLToPath(new URL("../evidence/", import.meta.url));
await mkdir(evidence, { recursive: true });
const browser = await chromium.launch({
  channel: "chrome",
  headless: false,
  args: ["--disable-backgrounding-occluded-windows", "--disable-renderer-backgrounding"],
});
const results = [];
const screenshots = [];

async function state(page) {
  return page.evaluate(() => ({
    figure: document.querySelector(".sheet__figure-value").textContent,
    disabled: [...document.querySelectorAll("button")].find((b) => b.textContent.includes("정산 엑셀 다운로드")).disabled,
    issues: document.querySelectorAll(".issue").length,
    rows: document.querySelectorAll("tbody tr").length,
    focused: document.activeElement.id,
    width: innerWidth,
    overflow: document.documentElement.scrollWidth > innerWidth,
  }));
}

async function run(page, action) {
  // Register and acknowledge the exact state subscription BEFORE the action.
  await page.evaluate(() => {
    window.__settlementReady = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        observer.disconnect();
        reject(new Error("Settlement did not finish"));
      }, 8000);
      const observer = new MutationObserver(() => {
        const busy = document.querySelector(".sheet").getAttribute("aria-busy");
        const figure = document.querySelector(".sheet__figure-value").textContent;
        if (busy === "false" && (figure !== "-" || document.querySelector(".issues"))) {
          clearTimeout(timer);
          observer.disconnect();
          resolve();
        }
      });
      observer.observe(document.getElementById("app"), {
        subtree: true, childList: true, attributes: true, characterData: true,
      });
    });
  });
  await action();
  await page.evaluate(() => window.__settlementReady);
  return state(page);
}

async function capture(page, name) {
  await page.evaluate(() => document.fonts.ready);
  const mobile = name.startsWith("390");
  const positions = [{ label: "work", selector: "#work" }];
  if (mobile) positions.push({ label: "summary", selector: ".sheet" });
  if (name.endsWith("initial")) {
    positions.unshift({ label: "top", selector: "#top" });
    positions.push({ label: "scope", selector: "#scope" });
    if (mobile) positions.push({ label: "calculation", selector: ".scope__card:nth-child(2)" });
    if (mobile) positions.push({ label: "scope-more", selector: ".scope__card:nth-child(3)" });
    positions.push({ label: "pilot", selector: "#pilot" });
    if (mobile) positions.push({ label: "footer", selector: "footer" });
  }
  for (const position of positions) {
    const metrics = await page.evaluate((selector) => {
      document.querySelector(selector).scrollIntoView({ behavior: "instant", block: "start" });
      return { width: innerWidth, height: innerHeight, scrollY };
    }, position.selector);
    const filename = `${name}-${position.label}.png`;
    const image = await page.screenshot({ path: `${evidence}/${filename}`, animations: "disabled" });
    const pixels = [image.readUInt32BE(16), image.readUInt32BE(20)];
    assert.deepEqual(pixels, [metrics.width, metrics.height], "Screenshot dimensions differ from viewport");
    screenshots.push({ filename, ...metrics, pixels });
    if (filename === "1280-initial-top.png") await writeFile(`${evidence}/desktop-initial.png`, image);
  }
}

try {
  for (const width of [1280, 390]) {
    const context = await browser.newContext({ viewport: { width, height: 1000 }, acceptDownloads: true });
    const page = await context.newPage();
    const failures = [];
    const requests = [];
    page.on("pageerror", (error) => failures.push(error.message));
    page.on("request", (request) => requests.push({ url: request.url(), method: request.method() }));
    await page.goto("http://127.0.0.1:8796/", { waitUntil: "load" });
    await page.getByRole("button", { name: "가상 샘플로 계산", exact: true }).waitFor({ state: "visible" });
    const initial = await state(page);
    assert.equal(initial.width, width);
    assert(initial.disabled && initial.figure === "-" && !initial.overflow);
    await capture(page, `${width}-initial`);

    const sample = await run(page, () => page.getByRole("button", { name: "가상 샘플로 계산", exact: true }).click());
    assert(sample.figure === "149,400원" && sample.rows === 6 && !sample.disabled && !sample.overflow);
    await capture(page, `${width}-sample`);

    const downloadReady = page.waitForEvent("download");
    await page.getByRole("button", { name: "정산 엑셀 다운로드", exact: true }).click();
    const download = await downloadReady;
    const reportPath = `${evidence}/${width}-browser-download.xlsx`;
    await download.saveAs(reportPath);
    assert.equal(await download.failure(), null);
    const report = read(await readFile(reportPath));
    assert.equal(report.Sheets["정산요약"]?.["B9"]?.v, 149400);

    const templateReady = page.waitForEvent("download");
    await page.getByRole("button", { name: "샘플 양식 다운로드", exact: true }).click();
    const template = await templateReady;
    const templatePath = `${evidence}/${width}-input-sample.xlsx`;
    await template.saveAs(templatePath);
    await page.locator("#order-files").setInputFiles(templatePath);
    assert((await state(page)).disabled, "A new file retained a downloadable result");
    const xlsxUpload = await run(page, () => page.getByRole("button", { name: "정산 계산", exact: true }).click());
    assert.equal(xlsxUpload.figure, "149,400원");

    const csv = "주문번호,주문일,상품명,수량,판매단가,할인액,배송비,수수료,상태\n0001,2026-09-01,검증 상품,2,12000,2000,3000,1200,완료";
    await page.locator("#order-files").setInputFiles({ name: "verification.csv", mimeType: "text/csv", buffer: Buffer.from(csv) });
    const cleared = await state(page);
    assert(cleared.disabled && cleared.figure === "-");
    const uploaded = await run(page, () => page.getByRole("button", { name: "정산 계산", exact: true }).click());
    assert(uploaded.figure === "23,800원" && uploaded.rows === 1 && !uploaded.disabled);

    await page.locator("#order-files").setInputFiles({
      name: "verification.csv", mimeType: "text/csv",
      buffer: Buffer.from(`${csv}\n0001,2026-09-02,중복 주문,1,1000,0,0,0,완료`),
    });
    const invalid = await run(page, () => page.getByRole("button", { name: "정산 계산", exact: true }).click());
    assert(invalid.disabled && invalid.figure === "-" && invalid.issues === 1 && invalid.focused === "issues-title");
    await capture(page, `${width}-invalid`);

    await page.evaluate((contents) => {
      const transfer = new DataTransfer();
      for (let index = 0; index < 6; index += 1) {
        transfer.items.add(new File([contents], `order-${index}.csv`, { type: "text/csv" }));
      }
      document.querySelector(".picker").dispatchEvent(new DragEvent("drop", { bubbles: true, dataTransfer: transfer }));
    }, csv);
    assert.equal(await page.locator("#order-files").evaluate((input) => input.files.length), 6);
    assert.equal(await page.locator(".picker__files li").count(), 6);
    const tooMany = await run(page, () => page.getByRole("button", { name: "정산 계산", exact: true }).click());
    assert(tooMany.disabled && tooMany.issues === 1);

    await page.getByRole("button", { name: "초기화", exact: true }).click();
    const reset = await state(page);
    assert(reset.disabled && reset.figure === "-" && reset.rows === 0 && reset.issues === 0);
    assert.deepEqual(failures, []);
    assert(requests.every((request) => request.url.startsWith("http://127.0.0.1:8796/") && request.method === "GET"), "Unexpected external request or upload");
    results.push({ width, initial, sample, xlsxUpload, uploaded, invalid, tooMany, reset, download: download.suggestedFilename(), requests: requests.length, pageErrors: failures });
    await context.close();
    console.info(`BROWSER_PASS: ${width}px initial/sample/download/xlsx-upload/csv-upload/error/6-file-drop/reset`);
  }
  await writeFile(`${evidence}/browser-results.json`, JSON.stringify(results, null, 2));
  await writeFile(`${evidence}/screenshots.json`, JSON.stringify(screenshots, null, 2));
  console.info(`BROWSER_QA_PASS: ${screenshots.length} fresh screenshots; real Chrome downloads and uploads verified`);
} finally {
  await browser.close();
}
