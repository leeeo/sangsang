import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { transactionsApi } from '../api/transactions'
import { categoriesApi } from '../api/categories'
import type { Category, Transaction, TransactionCreate } from '../types'
import { formatDate, formatKRW } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

export default function Transactions() {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [total, setTotal] = useState(0)
  const [skip, setSkip] = useState(0)
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [editing, setEditing] = useState<Transaction | null>(null)
  const LIMIT = 20

  const { register, handleSubmit, reset, setValue, formState: { errors } } = useForm<TransactionCreate>()

  const load = async () => {
    setLoading(true)
    try {
      const [txRes, catRes] = await Promise.all([
        transactionsApi.list({ skip, limit: LIMIT }),
        categoriesApi.list(),
      ])
      setTransactions(txRes.items)
      setTotal(txRes.total)
      setCategories(catRes)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [skip])

  const openCreate = () => {
    reset({ type: 'expense', transaction_date: new Date().toISOString().split('T')[0] })
    setEditing(null)
    setShowForm(true)
  }

  const openEdit = (tx: Transaction) => {
    setEditing(tx)
    setValue('category_id', tx.category_id)
    setValue('amount', Number(tx.amount))
    setValue('type', tx.type)
    setValue('transaction_date', tx.transaction_date)
    setValue('counterparty_name', tx.counterparty_name ?? '')
    setValue('memo', tx.memo ?? '')
    setValue('event_type', tx.event_type ?? '')
    setShowForm(true)
  }

  const onSubmit = async (data: TransactionCreate) => {
    try {
      if (editing) {
        await transactionsApi.update(editing.id, data)
        toast.success('거래가 수정되었습니다')
      } else {
        await transactionsApi.create(data)
        toast.success('거래가 등록되었습니다')
      }
      setShowForm(false)
      load()
    } catch {
      toast.error('저장에 실패했습니다')
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('삭제하시겠습니까?')) return
    try {
      await transactionsApi.delete(id)
      toast.success('삭제되었습니다')
      load()
    } catch {
      toast.error('삭제에 실패했습니다')
    }
  }

  const getCategoryName = (id: string) => categories.find(c => c.id === id)?.name ?? '-'

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0 }}>거래 내역</h2>
        <button onClick={openCreate} style={btnPrimaryStyle}>+ 거래 등록</button>
      </div>

      {loading ? <LoadingSpinner /> : (
        <>
          <div style={{ background: '#fff', borderRadius: 12, boxShadow: '0 1px 8px rgba(0,0,0,0.06)', overflow: 'hidden' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['날짜', '유형', '카테고리', '상대방', '금액', '메모', ''].map(h => (
                    <th key={h} style={{ padding: '0.75rem 1rem', textAlign: 'left', fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {transactions.length === 0 && (
                  <tr><td colSpan={7} style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>거래 내역이 없습니다</td></tr>
                )}
                {transactions.map(tx => (
                  <tr key={tx.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                    <td style={tdStyle}>{formatDate(tx.transaction_date)}</td>
                    <td style={tdStyle}>
                      <span style={{ padding: '0.2rem 0.6rem', borderRadius: 99, fontSize: '0.75rem', fontWeight: 600, background: tx.type === 'income' ? '#dcfce7' : '#fee2e2', color: tx.type === 'income' ? '#16a34a' : '#dc2626' }}>
                        {tx.type === 'income' ? '수입' : '지출'}
                      </span>
                    </td>
                    <td style={tdStyle}>{getCategoryName(tx.category_id)}</td>
                    <td style={tdStyle}>{tx.counterparty_name ?? '-'}</td>
                    <td style={{ ...tdStyle, fontWeight: 600, color: tx.type === 'income' ? '#16a34a' : '#dc2626' }}>
                      {tx.type === 'expense' ? '-' : '+'}{formatKRW(tx.amount)}
                    </td>
                    <td style={{ ...tdStyle, color: '#64748b', maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{tx.memo ?? '-'}</td>
                    <td style={tdStyle}>
                      <button onClick={() => openEdit(tx)} style={btnSmallStyle}>수정</button>
                      <button onClick={() => handleDelete(tx.id)} style={{ ...btnSmallStyle, color: '#ef4444' }}>삭제</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* 페이지네이션 */}
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', marginTop: '1rem' }}>
            <button disabled={skip === 0} onClick={() => setSkip(s => Math.max(0, s - LIMIT))} style={pageBtn}>이전</button>
            <span style={{ padding: '0.4rem 0.75rem', fontSize: '0.875rem', color: '#64748b' }}>
              {Math.floor(skip / LIMIT) + 1} / {Math.ceil(total / LIMIT) || 1}
            </span>
            <button disabled={skip + LIMIT >= total} onClick={() => setSkip(s => s + LIMIT)} style={pageBtn}>다음</button>
          </div>
        </>
      )}

      {/* 거래 입력/수정 모달 */}
      {showForm && (
        <div style={overlayStyle} onClick={() => setShowForm(false)}>
          <div style={modalStyle} onClick={e => e.stopPropagation()}>
            <h3 style={{ margin: '0 0 1.5rem' }}>{editing ? '거래 수정' : '거래 등록'}</h3>
            <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={labelStyle}>유형</label>
                  <select {...register('type', { required: true })} style={inputStyle}>
                    <option value="expense">지출</option>
                    <option value="income">수입</option>
                  </select>
                </div>
                <div>
                  <label style={labelStyle}>날짜</label>
                  <input type="date" {...register('transaction_date', { required: true })} style={inputStyle} />
                </div>
              </div>

              <div>
                <label style={labelStyle}>카테고리</label>
                <select {...register('category_id', { required: true })} style={inputStyle}>
                  <option value="">선택하세요</option>
                  {categories.map(c => (
                    <option key={c.id} value={c.id}>{c.icon} {c.name}</option>
                  ))}
                </select>
                {errors.category_id && <span style={errStyle}>카테고리를 선택하세요</span>}
              </div>

              <div>
                <label style={labelStyle}>금액 (원)</label>
                <input type="number" {...register('amount', { required: true, min: 1 })} style={inputStyle} placeholder="50000" />
                {errors.amount && <span style={errStyle}>금액을 입력하세요</span>}
              </div>

              <div>
                <label style={labelStyle}>상대방 이름</label>
                <input {...register('counterparty_name')} style={inputStyle} placeholder="홍길동" />
              </div>

              <div>
                <label style={labelStyle}>경조사 유형</label>
                <select {...register('event_type')} style={inputStyle}>
                  <option value="">없음</option>
                  <option value="wedding">결혼식</option>
                  <option value="funeral">장례식</option>
                  <option value="birthday">생일</option>
                  <option value="baby">돌잔치</option>
                  <option value="housewarming">집들이</option>
                  <option value="other">기타</option>
                </select>
              </div>

              <div>
                <label style={labelStyle}>메모</label>
                <input {...register('memo')} style={inputStyle} placeholder="메모 (선택)" />
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button type="submit" style={{ ...btnPrimaryStyle, flex: 1 }}>저장</button>
                <button type="button" onClick={() => setShowForm(false)} style={{ ...btnPrimaryStyle, flex: 1, background: '#e2e8f0', color: '#475569' }}>취소</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

const tdStyle: React.CSSProperties = { padding: '0.75rem 1rem', fontSize: '0.875rem' }
const btnPrimaryStyle: React.CSSProperties = { padding: '0.6rem 1.2rem', background: '#6366f1', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: '0.875rem' }
const btnSmallStyle: React.CSSProperties = { padding: '0.25rem 0.6rem', background: 'transparent', border: '1px solid #e2e8f0', borderRadius: 6, cursor: 'pointer', fontSize: '0.8rem', marginRight: '0.25rem' }
const pageBtn: React.CSSProperties = { padding: '0.4rem 0.75rem', border: '1px solid #e2e8f0', borderRadius: 6, background: '#fff', cursor: 'pointer', fontSize: '0.875rem' }
const overlayStyle: React.CSSProperties = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }
const modalStyle: React.CSSProperties = { background: '#fff', borderRadius: 16, padding: '2rem', width: 480, maxHeight: '90vh', overflow: 'auto', boxShadow: '0 20px 60px rgba(0,0,0,0.2)' }
const labelStyle: React.CSSProperties = { display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#374151', marginBottom: '0.3rem' }
const inputStyle: React.CSSProperties = { width: '100%', padding: '0.6rem 0.75rem', border: '1px solid #d1d5db', borderRadius: 8, fontSize: '0.875rem', boxSizing: 'border-box' }
const errStyle: React.CSSProperties = { fontSize: '0.75rem', color: '#ef4444' }
