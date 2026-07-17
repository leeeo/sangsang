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
    } catch (err: any) {
      setError(err.message || '로그인에 실패했습니다')
    }
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0f172a' }}>
      <div style={{ background: '#1e293b', borderRadius: 16, padding: '2.5rem', width: 380, boxShadow: '0 20px 60px rgba(0,0,0,0.4)' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>⚙️</div>
          <h1 style={{ margin: 0, color: '#f8fafc', fontSize: '1.5rem' }}>관리자 로그인</h1>
          <p style={{ margin: '0.25rem 0 0', color: '#64748b', fontSize: '0.875rem' }}>상부상조 Admin Console</p>
        </div>
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)}
            required placeholder="관리자 이메일" style={inputStyle} />
          <input type="password" value={password} onChange={e => setPassword(e.target.value)}
            required placeholder="비밀번호" style={inputStyle} />
          {error && <p style={{ color: '#f87171', fontSize: '0.875rem', margin: 0 }}>{error}</p>}
          <button type="submit" disabled={isLoading} style={btnStyle}>
            {isLoading ? '확인 중...' : '로그인'}
          </button>
        </form>
        <p style={{ color: '#475569', fontSize: '0.75rem', textAlign: 'center', marginTop: '1.5rem', lineHeight: 1.6 }}>
          ⚠️ 관리자(superuser) 계정만 접근 가능합니다<br />
          일반 사용자는 모바일 앱을 이용해주세요
        </p>
      </div>
    </div>
  )
}

const inputStyle: React.CSSProperties = {
  padding: '0.7rem 1rem', background: '#0f172a', border: '1px solid #334155',
  borderRadius: 8, color: '#f8fafc', fontSize: '0.9rem', outline: 'none',
}
const btnStyle: React.CSSProperties = {
  padding: '0.75rem', background: '#6366f1', color: '#fff',
  border: 'none', borderRadius: 8, fontSize: '1rem', fontWeight: 600, cursor: 'pointer', marginTop: '0.5rem',
}
