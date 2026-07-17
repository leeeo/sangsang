import { useEffect, useState } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend,
} from 'recharts'
import { adminApi } from '../api/admin'
import type { CategoryStat, TrendPoint } from '../types'
import { formatKRW, formatMonth } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

const MONTHS_OPTIONS = [3, 6, 12]

export default function Analytics() {
  const today = new Date()
  const [months, setMonths] = useState(6)
  const [trends, setTrends] = useState<TrendPoint[]>([])
  const [catType, setCatType] = useState<'expense' | 'income'>('expense')
  const [catYear, setCatYear] = useState(today.getFullYear())
  const [catMonth, setCatMonth] = useState(today.getMonth() + 1)
  const [categories, setCategories] = useState<CategoryStat[]>([])
  const [catTotal, setCatTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [catLoading, setCatLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    adminApi.analyticsTrends(months)
      .then(d => setTrends(d.trends))
      .finally(() => setLoading(false))
  }, [months])

  useEffect(() => {
    setCatLoading(true)
    adminApi.analyticsByCategory({ year: catYear, month: catMonth, type: catType })
      .then(d => { setCategories(d.categories); setCatTotal(d.total) })
      .finally(() => setCatLoading(false))
  }, [catType, catYear, catMonth])

  const trendData = trends.map(t => ({
    name: formatMonth(t.year, t.month),
    수입: t.income,
    지출: t.expense,
  }))

  return (
    <div>
      <h2 style={{ marginTop: 0, marginBottom: '1.5rem', color: '#1e293b' }}>서비스 분석</h2>

      {/* 월별 트렌드 */}
      <section style={sectionStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <h3 style={sectionTitle}>월별 수입 / 지출 트렌드</h3>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            {MONTHS_OPTIONS.map(m => (
              <button key={m} onClick={() => setMonths(m)} style={tabBtn(months === m)}>
                최근 {m}개월
              </button>
            ))}
          </div>
        </div>
        {loading ? <LoadingSpinner /> : (
          trendData.length === 0
            ? <Empty text="트렌드 데이터가 없습니다" />
            : (
              <ResponsiveContainer width="100%" height={280}>
                <BarChart data={trendData} margin={{ top: 4, right: 16, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                  <XAxis dataKey="name" tick={{ fontSize: 12, fill: '#64748b' }} />
                  <YAxis tickFormatter={v => `${(v / 10000).toFixed(0)}만`} tick={{ fontSize: 11, fill: '#94a3b8' }} />
                  <Tooltip formatter={(v) => formatKRW(Number(v))} />
                  <Legend />
                  <Bar dataKey="수입" fill="#10b981" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="지출" fill="#ef4444" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )
        )}
      </section>

      {/* 카테고리별 분석 */}
      <section style={sectionStyle}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
          <h3 style={sectionTitle}>카테고리별 분석</h3>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <select value={catYear} onChange={e => setCatYear(Number(e.target.value))} style={selectStyle}>
              {Array.from({ length: 3 }, (_, i) => today.getFullYear() - i).map(y => (
                <option key={y} value={y}>{y}년</option>
              ))}
            </select>
            <select value={catMonth} onChange={e => setCatMonth(Number(e.target.value))} style={selectStyle}>
              {Array.from({ length: 12 }, (_, i) => i + 1).map(m => (
                <option key={m} value={m}>{m}월</option>
              ))}
            </select>
            <div style={{ display: 'flex', border: '1px solid #e2e8f0', borderRadius: 8, overflow: 'hidden' }}>
              {(['expense', 'income'] as const).map(t => (
                <button key={t} onClick={() => setCatType(t)} style={tabBtn(catType === t, true)}>
                  {t === 'expense' ? '지출' : '수입'}
                </button>
              ))}
            </div>
          </div>
        </div>

        {catLoading ? <LoadingSpinner /> : (
          categories.length === 0
            ? <Empty text="해당 기간 데이터가 없습니다" />
            : (
              <>
                <p style={{ margin: '0 0 1rem', color: '#64748b', fontSize: '0.875rem' }}>
                  총 {catType === 'expense' ? '지출' : '수입'}: <strong style={{ color: catType === 'expense' ? '#ef4444' : '#10b981' }}>{formatKRW(catTotal)}</strong>
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                  {categories.map(cat => (
                    <CategoryRow key={cat.id} cat={cat} type={catType} />
                  ))}
                </div>
              </>
            )
        )}
      </section>
    </div>
  )
}

function CategoryRow({ cat, type }: { cat: CategoryStat; type: string }) {
  const color = cat.color || (type === 'expense' ? '#ef4444' : '#10b981')
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.25rem', fontSize: '0.875rem' }}>
        <span style={{ fontWeight: 500, color: '#1e293b' }}>{cat.name}</span>
        <span style={{ color: '#475569' }}>
          {formatKRW(cat.total)} <span style={{ color: '#94a3b8', fontSize: '0.75rem' }}>({cat.ratio}% · {cat.count}건)</span>
        </span>
      </div>
      <div style={{ height: 8, background: '#f1f5f9', borderRadius: 4, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${cat.ratio}%`, background: color, borderRadius: 4, transition: 'width 0.4s' }} />
      </div>
    </div>
  )
}

function Empty({ text }: { text: string }) {
  return (
    <div style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8', fontSize: '0.875rem' }}>{text}</div>
  )
}

const sectionStyle: React.CSSProperties = {
  background: '#fff', borderRadius: 12, padding: '1.5rem',
  boxShadow: '0 1px 8px rgba(0,0,0,0.06)', marginBottom: '1.5rem',
}
const sectionTitle: React.CSSProperties = { margin: 0, fontSize: '1rem', fontWeight: 600, color: '#1e293b' }
const selectStyle: React.CSSProperties = {
  padding: '0.4rem 0.6rem', border: '1px solid #e2e8f0', borderRadius: 6,
  fontSize: '0.875rem', background: '#fff', color: '#475569',
}

const tabBtn = (active: boolean, compact = false): React.CSSProperties => ({
  padding: compact ? '0.4rem 0.75rem' : '0.35rem 0.8rem',
  border: compact ? 'none' : '1px solid #e2e8f0',
  borderRadius: compact ? 0 : 6,
  background: active ? '#6366f1' : '#fff',
  color: active ? '#fff' : '#64748b',
  cursor: 'pointer', fontSize: '0.8rem', fontWeight: active ? 600 : 400,
})
