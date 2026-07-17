import { useEffect, useState } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  PieChart, Pie, Cell, ResponsiveContainer, Legend,
} from 'recharts'
import { analyticsApi } from '../api/analytics'
import type { AnalyticsSummary, CategoryStat, TrendItem } from '../types'
import { formatKRW, formatMonth } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

export default function Dashboard() {
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null)
  const [trends, setTrends] = useState<TrendItem[]>([])
  const [categories, setCategories] = useState<CategoryStat[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      analyticsApi.summary(),
      analyticsApi.trends(6),
      analyticsApi.byCategory('expense'),
    ]).then(([s, t, c]) => {
      setSummary(s)
      setTrends(t)
      setCategories(c.categories.slice(0, 6))
    }).finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingSpinner />

  const trendData = trends.map(t => ({
    name: formatMonth(t.year, t.month),
    수입: t.income,
    지출: t.expense,
  }))

  const COLORS = ['#6366f1','#f59e0b','#10b981','#ef4444','#8b5cf6','#3b82f6']

  return (
    <div>
      <h2 style={{ marginTop: 0, marginBottom: '1.5rem' }}>대시보드</h2>

      {/* 요약 카드 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem', marginBottom: '2rem' }}>
        <SummaryCard label="이번 달 수입" value={formatKRW(summary?.income ?? 0)} color="#10b981" />
        <SummaryCard label="이번 달 지출" value={formatKRW(summary?.expense ?? 0)} color="#ef4444" />
        <SummaryCard
          label="잔액"
          value={formatKRW(summary?.balance ?? 0)}
          color={(summary?.balance ?? 0) >= 0 ? '#6366f1' : '#ef4444'}
        />
      </div>

      {/* 차트 */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1.5rem' }}>
        {/* 월별 트렌드 */}
        <div style={cardStyle}>
          <h3 style={cardTitleStyle}>월별 수입/지출</h3>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={trendData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="name" tick={{ fontSize: 12 }} />
              <YAxis tickFormatter={v => (v / 10000) + '만'} tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v) => formatKRW(Number(v))} />
              <Legend />
              <Bar dataKey="수입" fill="#10b981" radius={[4,4,0,0]} />
              <Bar dataKey="지출" fill="#ef4444" radius={[4,4,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* 카테고리별 지출 */}
        <div style={cardStyle}>
          <h3 style={cardTitleStyle}>카테고리별 지출</h3>
          {categories.length === 0 ? (
            <p style={{ color: '#94a3b8', textAlign: 'center', paddingTop: '4rem' }}>
              이번 달 지출 데이터가 없습니다
            </p>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <PieChart>
                <Pie data={categories} dataKey="total" nameKey="name" cx="50%" cy="50%" outerRadius={80} label={({ name, payload }) => `${name} ${(payload as CategoryStat).ratio}%`}>
                  {categories.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Pie>
              <Tooltip formatter={(v) => formatKRW(Number(v))} />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>
    </div>
  )
}

function SummaryCard({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div style={{ ...cardStyle, borderTop: `4px solid ${color}` }}>
      <p style={{ margin: '0 0 0.5rem', fontSize: '0.875rem', color: '#64748b' }}>{label}</p>
      <p style={{ margin: 0, fontSize: '1.5rem', fontWeight: 700, color }}>{value}</p>
    </div>
  )
}

const cardStyle: React.CSSProperties = {
  background: '#fff', borderRadius: 12, padding: '1.5rem',
  boxShadow: '0 1px 8px rgba(0,0,0,0.06)',
}
const cardTitleStyle: React.CSSProperties = {
  margin: '0 0 1rem', fontSize: '1rem', fontWeight: 600, color: '#1e293b',
}
