import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../store/auth'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const { login, isLoading } = useAuthStore()
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    try {
      await login(email, password)
      navigate('/')
    } catch {
      setError('이메일 또는 비밀번호가 올바르지 않습니다')
    }
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center',
      justifyContent: 'center', background: '#f1f5f9',
    }}>
      <div style={{
        background: '#fff', borderRadius: 16, padding: '2.5rem',
        width: 380, boxShadow: '0 4px 24px rgba(0,0,0,0.08)',
      }}>
        <h1 style={{ textAlign: 'center', marginBottom: '0.5rem', fontSize: '1.5rem' }}>상부상조</h1>
        <p style={{ textAlign: 'center', color: '#64748b', marginBottom: '2rem', fontSize: '0.875rem' }}>
          경조사비 관리 플랫폼
        </p>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div>
            <label style={labelStyle}>이메일</label>
            <input
              type="email" value={email} onChange={e => setEmail(e.target.value)}
              required style={inputStyle} placeholder="email@example.com"
            />
          </div>
          <div>
            <label style={labelStyle}>비밀번호</label>
            <input
              type="password" value={password} onChange={e => setPassword(e.target.value)}
              required style={inputStyle} placeholder="••••••••"
            />
          </div>

          {error && <p style={{ color: '#ef4444', fontSize: '0.875rem', margin: 0 }}>{error}</p>}

          <button type="submit" disabled={isLoading} style={btnStyle}>
            {isLoading ? '로그인 중...' : '로그인'}
          </button>
        </form>
      </div>
    </div>
  )
}

const labelStyle: React.CSSProperties = {
  display: 'block', fontSize: '0.875rem', fontWeight: 500,
  color: '#374151', marginBottom: '0.35rem',
}
const inputStyle: React.CSSProperties = {
  width: '100%', padding: '0.65rem 0.85rem', border: '1px solid #d1d5db',
  borderRadius: 8, fontSize: '0.9rem', boxSizing: 'border-box',
  outline: 'none',
}
const btnStyle: React.CSSProperties = {
  padding: '0.75rem', background: '#6366f1', color: '#fff',
  border: 'none', borderRadius: 8, fontSize: '1rem',
  fontWeight: 600, cursor: 'pointer', marginTop: '0.5rem',
}
