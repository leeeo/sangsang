export const formatKRW = (v: number) => Number(v).toLocaleString('ko-KR') + '원'
export const formatDate = (s: string) => new Date(s).toLocaleDateString('ko-KR')
export const formatMonth = (y: number, m: number) => `${y}.${String(m).padStart(2, '0')}`
