const XLSX_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

// Local-only download: the bytes never leave the browser.
export function downloadXlsx(bytes: Uint8Array, fileName: string): void {
  // Copy onto a plain ArrayBuffer so the Blob part type is exact regardless of the encoder's buffer kind.
  const part = new Uint8Array(bytes);
  const url = URL.createObjectURL(new Blob([part], { type: XLSX_TYPE }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}
