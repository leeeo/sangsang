import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { adminApi } from '../api/admin'
import type { AdminUser } from '../types'
import { formatDate } from '../utils/format'
import LoadingSpinner from '../components/common/LoadingSpinner'

export default function Users() {
  const [users, setUsers] = useState<AdminUser[]>([])
  const [total, setTotal] = useState(0)
  const [search, setSearch] = useState('')
  const [skip, setSkip] = useState(0)
  const [loading, setLoading] = useState(true)
  const LIMIT = 20

  const load = async () => {
    setLoading(true)
    try {
      const res = await adminApi.users({ skip, limit: LIMIT, search: search || undefined })
      setUsers(res.items)
      setTotal(res.total)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [skip])

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    setSkip(0)
    load()
  }

  const toggleActive = async (user: AdminUser) => {
    try {
      await adminApi.updateUser(user.id, { is_active: !user.is_active })
      toast.success(`${user.email} ${user.is_active ? '비활성화' : '활성화'}됨`)
      load()
    } catch {
      toast.error('변경에 실패했습니다')
    }
  }

  const handleDelete = async (user: AdminUser) => {
    if (!confirm(`${user.email} 계정을 삭제하시겠습니까?`)) return
    try {
      await adminApi.deleteUser(user.id)
      toast.success('삭제되었습니다')
      load()
    } catch {
      toast.error('삭제에 실패했습니다')
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0 }}>사용자 관리 <span style={{ fontSize: '1rem', color: '#64748b', fontWeight: 400 }}>총 {total}명</span></h2>
        <form onSubmit={handleSearch} style={{ display: 'flex', gap: '0.5rem' }}>
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="이메일, 이름 검색..."
            style={{ padding: '0.5rem 0.75rem', border: '1px solid #d1d5db', borderRadius: 8, fontSize: '0.875rem', width: 220 }} />
          <button type="submit" style={btnStyle}>검색</button>
        </form>
      </div>

      {loading ? <LoadingSpinner /> : (
        <>
          <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', boxShadow: '0 1px 8px rgba(0,0,0,0.06)' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '2px solid #e2e8f0' }}>
                  {['이메일', '사용자명', '이름', '거래수', '가입일', '상태', '권한', ''].map(h => (
                    <th key={h} style={{ padding: '0.75rem 1rem', textAlign: 'left', fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {users.length === 0 && (
                  <tr><td colSpan={8} style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>사용자가 없습니다</td></tr>
                )}
                {users.map(u => (
                  <tr key={u.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                    <td style={td}>{u.email}</td>
                    <td style={td}>{u.username}</td>
                    <td style={td}>{u.full_name ?? '-'}</td>
                    <td style={td}>{u.tx_count}</td>
                    <td style={td}>{formatDate(u.created_at)}</td>
                    <td style={td}>
                      <span style={{ padding: '0.2rem 0.6rem', borderRadius: 99, fontSize: '0.75rem', fontWeight: 600, background: u.is_active ? '#dcfce7' : '#fee2e2', color: u.is_active ? '#16a34a' : '#dc2626' }}>
                        {u.is_active ? '활성' : '비활성'}
                      </span>
                    </td>
                    <td style={td}>
                      {u.is_superuser && <span style={{ padding: '0.2rem 0.6rem', borderRadius: 99, fontSize: '0.75rem', background: '#ede9fe', color: '#7c3aed', fontWeight: 600 }}>관리자</span>}
                    </td>
                    <td style={td}>
                      <button onClick={() => toggleActive(u)} style={{ ...btnSmall, color: u.is_active ? '#ef4444' : '#10b981' }}>
                        {u.is_active ? '비활성화' : '활성화'}
                      </button>
                      {!u.is_superuser && (
                        <button onClick={() => handleDelete(u)} style={{ ...btnSmall, color: '#64748b', marginLeft: '0.25rem' }}>삭제</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem', marginTop: '1rem' }}>
            <button disabled={skip === 0} onClick={() => setSkip(s => Math.max(0, s - LIMIT))} style={pageBtn}>이전</button>
            <span style={{ padding: '0.4rem 0.75rem', fontSize: '0.875rem', color: '#64748b' }}>
              {Math.floor(skip / LIMIT) + 1} / {Math.ceil(total / LIMIT) || 1}
            </span>
            <button disabled={skip + LIMIT >= total} onClick={() => setSkip(s => s + LIMIT)} style={pageBtn}>다음</button>
          </div>
        </>
      )}
    </div>
  )
}

const td: React.CSSProperties = { padding: '0.75rem 1rem', fontSize: '0.875rem' }
const btnStyle: React.CSSProperties = { padding: '0.5rem 1rem', background: '#6366f1', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: '0.875rem', fontWeight: 600 }
const btnSmall: React.CSSProperties = { padding: '0.25rem 0.6rem', background: 'transparent', border: '1px solid #e2e8f0', borderRadius: 6, cursor: 'pointer', fontSize: '0.8rem' }
const pageBtn: React.CSSProperties = { padding: '0.4rem 0.75rem', border: '1px solid #e2e8f0', borderRadius: 6, background: '#fff', cursor: 'pointer', fontSize: '0.875rem' }
