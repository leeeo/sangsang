const integer = new Intl.NumberFormat("ko-KR", { maximumFractionDigits: 0 });

export function formatKrw(value: number): string {
  return `${integer.format(value)}원`;
}

export function formatCount(value: number, unit: string): string {
  return `${integer.format(value)}${unit}`;
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function todayStamp(): string {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${now.getFullYear()}${month}${day}`;
}
