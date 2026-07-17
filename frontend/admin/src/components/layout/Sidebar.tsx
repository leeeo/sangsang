import { NavLink } from 'react-router-dom'
import { useAuthStore } from '../../store/auth'

const nav = [
  { to: '/', label: '대시보드', icon: '📊' },
  { to: '/transactions', label: '거래 내역', icon: '💸' },
  { to: '/categories', label: '카테고리', icon: '🏷️' },
  { to: '/relationships', label: '관계 관리', icon: '🤝' },
]

export default function Sidebar() {
  const { user, logout } = useAuthStore()

  return (
    <aside style={{
      width: 220, minHeight: '100vh', background: '#1e293b', color: '#f8fafc',
      display: 'flex', flexDirection: 'column', padding: '1.5rem 0',
    }}>
      <div style={{ padding: '0 1.5rem 2rem', borderBottom: '1px solid #334155' }}>
        <h1 style={{ fontSize: '1.25rem', fontWeight: 700, margin: 0 }}>상부상조</h1>
        <p style={{ fontSize: '0.75rem', color: '#94a3b8', margin: '0.25rem 0 0' }}>
          {user?.full_name || user?.username}
        </p>
      </div>

      <nav style={{ flex: 1, padding: '1rem 0' }}>
        {nav.map(({ to, label, icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            style={({ isActive }) => ({
              display: 'flex', alignItems: 'center', gap: '0.75rem',
              padding: '0.65rem 1.5rem', textDecoration: 'none',
              color: isActive ? '#f8fafc' : '#94a3b8',
              background: isActive ? '#334155' : 'transparent',
              borderLeft: isActive ? '3px solid #6366f1' : '3px solid transparent',
              transition: 'all 0.15s',
            })}
          >
            <span>{icon}</span>
            <span style={{ fontSize: '0.875rem' }}>{label}</span>
          </NavLink>
        ))}
      </nav>

      <button
        onClick={logout}
        style={{
          margin: '0 1rem', padding: '0.65rem', background: '#334155',
          color: '#94a3b8', border: 'none', borderRadius: 8,
          cursor: 'pointer', fontSize: '0.875rem',
        }}
      >
        로그아웃
      </button>
    </aside>
  )
}
