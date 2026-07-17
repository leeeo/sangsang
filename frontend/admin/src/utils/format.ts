export const formatKRW = (amount: number | string) =>
  Number(amount).toLocaleString('ko-KR') + '원'

export const formatDate = (dateStr: string) => {
  const d = new Date(dateStr)
  return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`
}

export const formatMonth = (year: number, month: number) =>
  `${year}.${String(month).padStart(2, '0')}`
