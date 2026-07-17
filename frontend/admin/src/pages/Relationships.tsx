import { useEffect, useState } from 'react'
import { formatKRW } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

interface CounterpartyStat {
  name: string
  given: number
  received: number
  balance: number
  count: number
  last_date: string | null
}

export default function Relationships() {
  const [people, setPeople] = useState<CounterpartyStat[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/api/v1/analytics/counterparty`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('access_token')}` },
    })
      .then(r => r.json())
      .then(d => setPeople(d.counterparties ?? []))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingSpinner />

  return (
    <div>
      <h2 style={{ marginTop: 0, marginBottom: '1.5rem' }}>관계 관리</h2>
      <p style={{ color: '#64748b', marginBottom: '1.5rem', fontSize: '0.875rem' }}>
        거래 상대방별 주고받은 금액 요약입니다.
      </p>

      {people.length === 0 ? (
        <div style={{ background: '#fff', borderRadius: 12, padding: '3rem', textAlign: 'center', color: '#94a3b8' }}>
          아직 거래 상대방 데이터가 없습니다.<br />
          거래 등록 시 상대방 이름을 입력하면 여기에 표시됩니다.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
          {people.map(p => (
            <div key={p.name} style={{ background: '#fff', borderRadius: 12, padding: '1.25rem 1.5rem', boxShadow: '0 1px 8px rgba(0,0,0,0.06)', display: 'flex', alignItems: 'center', gap: '1.5rem' }}>
              <div style={{ width: 44, height: 44, borderRadius: '50%', background: '#f1f5f9', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.25rem', flexShrink: 0 }}>
                👤
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ margin: '0 0 0.25rem', fontWeight: 700 }}>{p.name}</p>
                <p style={{ margin: 0, fontSize: '0.8rem', color: '#94a3b8' }}>
                  거래 {p.count}건 · 마지막 {p.last_date ?? '-'}
                </p>
              </div>
              <div style={{ textAlign: 'right' }}>
                <p style={{ margin: '0 0 0.2rem', fontSize: '0.8rem', color: '#64748b' }}>
                  줌 {formatKRW(p.given)} / 받음 {formatKRW(p.received)}
                </p>
                <p style={{ margin: 0, fontWeight: 700, color: p.balance > 0 ? '#ef4444' : p.balance < 0 ? '#10b981' : '#64748b' }}>
                  {p.balance > 0 ? `${formatKRW(p.balance)} 더 줌` : p.balance < 0 ? `${formatKRW(-p.balance)} 더 받음` : '균형'}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
