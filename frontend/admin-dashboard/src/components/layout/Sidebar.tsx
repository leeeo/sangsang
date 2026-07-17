import { NavLink } from 'react-router-dom'
import { useAuthStore } from '../../store/auth'

const nav = [
  { to: '/', label: '대시보드', icon: '📊' },
  { to: '/users', label: '사용자 관리', icon: '👥' },
  { to: '/transactions', label: '거래 내역', icon: '💸' },
  { to: '/analytics', label: '분석', icon: '📈' },
  { to: '/categories', label: '카테고리 관리', icon: '🏷️' },
]

export default function Sidebar() {
  const { user, logout } = useAuthStore()
  return (
    <aside style={{ width: 220, minHeight: '100vh', background: '#0f172a', color: '#f8fafc', display: 'flex', flexDirection: 'column', padding: '1.5rem 0' }}>
      <div style={{ padding: '0 1.5rem 1.5rem', borderBottom: '1px solid #1e293b' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
          <span style={{ fontSize: '1.25rem' }}>⚙️</span>
          <h1 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>관리자 콘솔</h1>
        </div>
        <p style={{ margin: 0, fontSize: '0.75rem', color: '#94a3b8' }}>상부상조 Admin</p>
        <p style={{ margin: '0.25rem 0 0', fontSize: '0.75rem', color: '#64748b' }}>{user?.full_name || user?.email}</p>
      </div>
      <nav style={{ flex: 1, padding: '1rem 0' }}>
        {nav.map(({ to, label, icon }) => (
          <NavLink key={to} to={to} end={to === '/'}
            style={({ isActive }) => ({
              display: 'flex', alignItems: 'center', gap: '0.75rem',
              padding: '0.65rem 1.5rem', textDecoration: 'none',
              color: isActive ? '#f8fafc' : '#64748b',
              background: isActive ? '#1e293b' : 'transparent',
              borderLeft: `3px solid ${isActive ? '#6366f1' : 'transparent'}`,
            })}>
            <span>{icon}</span>
            <span style={{ fontSize: '0.875rem' }}>{label}</span>
          </NavLink>
        ))}
      </nav>
      <button onClick={logout} style={{ margin: '0 1rem', padding: '0.6rem', background: '#1e293b', color: '#64748b', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: '0.875rem' }}>
        로그아웃
      </button>
    </aside>
  )
}
