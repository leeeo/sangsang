import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { adminApi } from '../api/admin'
import type { Category } from '../types'

export default function Categories() {
  const [categories, setCategories] = useState<Category[]>([])
  const [showForm, setShowForm] = useState(false)
  const { register, handleSubmit, reset } = useForm<{ name: string; type: string; icon: string; color: string }>()

  const load = () => adminApi.categories().then(setCategories)
  useEffect(() => { load() }, [])

  const onSubmit = async (data: { name: string; type: string; icon: string; color: string }) => {
    try {
      await adminApi.createCategory(data)
      toast.success('카테고리 생성 완료')
      setShowForm(false)
      reset()
      load()
    } catch { toast.error('생성 실패') }
  }

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`'${name}' 카테고리를 삭제하시겠습니까?`)) return
    try {
      await adminApi.deleteCategory(id)
      toast.success('삭제되었습니다')
      load()
    } catch { toast.error('삭제 실패') }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0 }}>시스템 카테고리 관리</h2>
        <button onClick={() => setShowForm(true)} style={btnPrimary}>+ 카테고리 추가</button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '0.75rem' }}>
        {categories.map(c => (
          <div key={c.id} style={{ background: '#fff', borderRadius: 10, padding: '1rem', boxShadow: '0 1px 4px rgba(0,0,0,0.06)', borderLeft: `4px solid ${c.color ?? '#e2e8f0'}`, display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <span style={{ fontSize: '1.5rem' }}>{c.icon ?? '📦'}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ margin: 0, fontWeight: 600, fontSize: '0.875rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</p>
              <p style={{ margin: 0, fontSize: '0.75rem', color: '#94a3b8' }}>{c.type === 'income' ? '수입' : '지출'}</p>
            </div>
            <button onClick={() => handleDelete(c.id, c.name)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#cbd5e1', fontSize: '1.1rem' }}>×</button>
          </div>
        ))}
      </div>

      {showForm && (
        <div style={overlay} onClick={() => setShowForm(false)}>
          <div style={modal} onClick={e => e.stopPropagation()}>
            <h3 style={{ margin: '0 0 1.5rem' }}>시스템 카테고리 추가</h3>
            <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div><label style={labelStyle}>이름</label><input {...register('name', { required: true })} style={inputStyle} /></div>
              <div>
                <label style={labelStyle}>유형</label>
                <select {...register('type', { required: true })} style={inputStyle}>
                  <option value="expense">지출</option>
                  <option value="income">수입</option>
                </select>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div><label style={labelStyle}>아이콘</label><input {...register('icon')} style={inputStyle} placeholder="💰" /></div>
                <div><label style={labelStyle}>색상</label><input type="color" {...register('color')} style={{ ...inputStyle, padding: '0.25rem', height: 40 }} defaultValue="#6366f1" /></div>
              </div>
              <div style={{ display: 'flex', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button type="submit" style={{ ...btnPrimary, flex: 1 }}>저장</button>
                <button type="button" onClick={() => setShowForm(false)} style={{ ...btnPrimary, flex: 1, background: '#e2e8f0', color: '#475569' }}>취소</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

const btnPrimary: React.CSSProperties = { padding: '0.6rem 1.2rem', background: '#6366f1', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: '0.875rem' }
const overlay: React.CSSProperties = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }
const modal: React.CSSProperties = { background: '#fff', borderRadius: 16, padding: '2rem', width: 400, boxShadow: '0 20px 60px rgba(0,0,0,0.2)' }
const labelStyle: React.CSSProperties = { display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#374151', marginBottom: '0.3rem' }
const inputStyle: React.CSSProperties = { width: '100%', padding: '0.6rem 0.75rem', border: '1px solid #d1d5db', borderRadius: 8, fontSize: '0.875rem', boxSizing: 'border-box' }
