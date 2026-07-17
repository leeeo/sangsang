import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { adminApi } from '../api/admin'
import type { AdminTransaction } from '../types'
import { formatKRW } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

const TYPE_LABEL: Record<string, string> = { income: '수입', expense: '지출' }
const TYPE_COLOR: Record<string, string> = { income: '#10b981', expense: '#ef4444' }

const LIMIT = 20

export default function Transactions() {
  const [items, setItems] = useState<AdminTransaction[]>([])
  const [total, setTotal] = useState(0)
  const [skip, setSkip] = useState(0)
  const [typeFilter, setTypeFilter] = useState('')
  const [loading, setLoading] = useState(true)

  const load = async () => {
    setLoading(true)
    try {
      const res = await adminApi.transactions({
        skip,
        limit: LIMIT,
        type: typeFilter || undefined,
      })
      setItems(res.items)
      setTotal(res.total)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [skip, typeFilter])

  const handleDelete = async (tx: AdminTransaction) => {
    if (!confirm(`이 거래를 삭제하시겠습니까?\n${tx.counterparty_name ?? ''} ${formatKRW(Number(tx.amount))}`)) return
    try {
      await adminApi.deleteTransaction(tx.id)
      toast.success('삭제되었습니다')
      load()
    } catch {
      toast.error('삭제에 실패했습니다')
    }
  }

  const totalPages = Math.ceil(total / LIMIT)
  const currentPage = Math.floor(skip / LIMIT) + 1

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0 }}>
          전체 거래 내역{' '}
          <span style={{ fontSize: '1rem', color: '#64748b', fontWeight: 400 }}>총 {total}건</span>
        </h2>
        <select
          value={typeFilter}
          onChange={e => { setTypeFilter(e.target.value); setSkip(0) }}
          style={{ padding: '0.5rem 0.75rem', border: '1px solid #d1d5db', borderRadius: 8, fontSize: '0.875rem', background: '#fff' }}
        >
          <option value="">전체 유형</option>
          <option value="income">수입</option>
          <option value="expense">지출</option>
        </select>
      </div>

      {loading ? <LoadingSpinner /> : (
        <>
          <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 8px rgba(0,0,0,0.06)' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['유형', '금액', '상대방', '날짜', '이벤트', '메모', ''].map(h => (
                    <th key={h} style={thStyle}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {items.length === 0 ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                      거래 내역이 없습니다
                    </td>
                  </tr>
                ) : items.map(tx => (
                  <tr key={tx.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                    <td style={tdStyle}>
                      <span style={{
                        display: 'inline-block', padding: '2px 8px', borderRadius: 12,
                        fontSize: '0.75rem', fontWeight: 600,
                        background: TYPE_COLOR[tx.type] + '1a',
                        color: TYPE_COLOR[tx.type],
                      }}>
                        {TYPE_LABEL[tx.type] ?? tx.type}
                      </span>
                    </td>
                    <td style={{ ...tdStyle, fontWeight: 600, color: TYPE_COLOR[tx.type] }}>
                      {tx.type === 'expense' ? '-' : '+'}{formatKRW(Number(tx.amount))}
                    </td>
                    <td style={tdStyle}>{tx.counterparty_name ?? '-'}</td>
                    <td style={tdStyle}>{tx.transaction_date}</td>
                    <td style={tdStyle}>{tx.event_type ?? '-'}</td>
                    <td style={{ ...tdStyle, color: '#64748b', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {tx.memo ?? '-'}
                    </td>
                    <td style={tdStyle}>
                      <button
                        onClick={() => handleDelete(tx)}
                        style={{ padding: '4px 10px', background: '#fef2f2', color: '#ef4444', border: '1px solid #fecaca', borderRadius: 6, cursor: 'pointer', fontSize: '0.75rem' }}
                      >삭제</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* 페이지네이션 */}
          {totalPages > 1 && (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '0.5rem', marginTop: '1.5rem' }}>
              <button onClick={() => setSkip(0)} disabled={currentPage === 1} style={pageBtn(currentPage === 1)}>«</button>
              <button onClick={() => setSkip(skip - LIMIT)} disabled={currentPage === 1} style={pageBtn(currentPage === 1)}>‹</button>
              <span style={{ padding: '0.4rem 1rem', fontSize: '0.875rem', color: '#475569' }}>
                {currentPage} / {totalPages}
              </span>
              <button onClick={() => setSkip(skip + LIMIT)} disabled={currentPage === totalPages} style={pageBtn(currentPage === totalPages)}>›</button>
              <button onClick={() => setSkip((totalPages - 1) * LIMIT)} disabled={currentPage === totalPages} style={pageBtn(currentPage === totalPages)}>»</button>
            </div>
          )}
        </>
      )}
    </div>
  )
}

const thStyle: React.CSSProperties = {
  padding: '0.75rem 1rem', textAlign: 'left', fontSize: '0.8rem',
  fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em',
}

const tdStyle: React.CSSProperties = {
  padding: '0.75rem 1rem', fontSize: '0.875rem', color: '#1e293b',
}

const pageBtn = (disabled: boolean): React.CSSProperties => ({
  padding: '0.4rem 0.75rem', border: '1px solid #e2e8f0', borderRadius: 6,
  background: disabled ? '#f8fafc' : '#fff', color: disabled ? '#cbd5e1' : '#475569',
  cursor: disabled ? 'not-allowed' : 'pointer', fontSize: '0.875rem',
})
