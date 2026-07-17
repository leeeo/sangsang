import { useEffect, useState } from 'react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { adminApi } from '../api/admin'
import type { AdminStats } from '../types'
import { formatKRW, formatMonth } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

export default function Dashboard() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    adminApi.stats().then(setStats).finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingSpinner />

  const signupData = stats?.monthly_signups.map(s => ({
    name: formatMonth(s.year, s.month),
    신규가입: s.count,
  })) ?? []

  return (
    <div>
      <h2 style={{ marginTop: 0, marginBottom: '1.5rem', color: '#1e293b' }}>서비스 현황</h2>

      {/* 요약 카드 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1rem', marginBottom: '2rem' }}>
        <StatCard label="전체 사용자" value={String(stats?.users.total ?? 0)} sub={`활성 ${stats?.users.active ?? 0}명`} color="#6366f1" icon="👥" />
        <StatCard label="비활성 사용자" value={String(stats?.users.inactive ?? 0)} color="#f59e0b" icon="🔒" />
        <StatCard label="전체 거래 건수" value={String((stats?.transactions.income_count ?? 0) + (stats?.transactions.expense_count ?? 0))} sub="전체 기간" color="#10b981" icon="💸" />
        <StatCard label="총 거래 금액" value={formatKRW((stats?.transactions.income_total ?? 0) + (stats?.transactions.expense_total ?? 0))} color="#3b82f6" icon="💰" />
      </div>

      {/* 수입/지출 요약 */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '2rem' }}>
        <div style={cardStyle}>
          <p style={cardLabelStyle}>수입 합계</p>
          <p style={{ margin: 0, fontSize: '1.5rem', fontWeight: 700, color: '#10b981' }}>{formatKRW(stats?.transactions.income_total ?? 0)}</p>
          <p style={{ margin: '0.25rem 0 0', color: '#94a3b8', fontSize: '0.875rem' }}>{stats?.transactions.income_count ?? 0}건</p>
        </div>
        <div style={cardStyle}>
          <p style={cardLabelStyle}>지출 합계</p>
          <p style={{ margin: 0, fontSize: '1.5rem', fontWeight: 700, color: '#ef4444' }}>{formatKRW(stats?.transactions.expense_total ?? 0)}</p>
          <p style={{ margin: '0.25rem 0 0', color: '#94a3b8', fontSize: '0.875rem' }}>{stats?.transactions.expense_count ?? 0}건</p>
        </div>
      </div>

      {/* 신규 가입 추이 */}
      <div style={cardStyle}>
        <h3 style={{ margin: '0 0 1rem', fontSize: '1rem', fontWeight: 600 }}>월별 신규 가입</h3>
        {signupData.length === 0 ? (
          <p style={{ color: '#94a3b8', textAlign: 'center', padding: '2rem' }}>데이터 없음</p>
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={signupData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="name" tick={{ fontSize: 12 }} />
              <YAxis allowDecimals={false} tick={{ fontSize: 12 }} />
              <Tooltip />
              <Bar dataKey="신규가입" fill="#6366f1" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  )
}

function StatCard({ label, value, sub, color, icon }: { label: string; value: string; sub?: string; color: string; icon: string }) {
  return (
    <div style={{ ...cardStyle, borderTop: `4px solid ${color}` }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <p style={cardLabelStyle}>{label}</p>
          <p style={{ margin: '0.25rem 0 0', fontSize: '1.5rem', fontWeight: 700, color }}>{value}</p>
          {sub && <p style={{ margin: '0.25rem 0 0', fontSize: '0.75rem', color: '#94a3b8' }}>{sub}</p>}
        </div>
        <span style={{ fontSize: '1.75rem' }}>{icon}</span>
      </div>
    </div>
  )
}

const cardStyle: React.CSSProperties = { background: '#fff', borderRadius: 12, padding: '1.5rem', boxShadow: '0 1px 8px rgba(0,0,0,0.06)' }
const cardLabelStyle: React.CSSProperties = { margin: 0, fontSize: '0.8rem', color: '#64748b', fontWeight: 500 }
