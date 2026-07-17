import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { categoriesApi } from '../api/categories'
import type { Category } from '../types'

export default function Categories() {
  const [categories, setCategories] = useState<Category[]>([])
  const [showForm, setShowForm] = useState(false)
  const { register, handleSubmit, reset } = useForm<{ name: string; type: string; icon: string; color: string }>()

  const load = async () => {
    const data = await categoriesApi.list()
    setCategories(data)
  }

  useEffect(() => { load() }, [])

  const onSubmit = async (data: { name: string; type: string; icon: string; color: string }) => {
    try {
      await categoriesApi.create(data)
      toast.success('카테고리가 생성되었습니다')
      setShowForm(false)
      reset()
      load()
    } catch {
      toast.error('생성에 실패했습니다')
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('삭제하시겠습니까?')) return
    try {
      await categoriesApi.delete(id)
      toast.success('삭제되었습니다')
      load()
    } catch {
      toast.error('시스템 카테고리는 삭제할 수 없습니다')
    }
  }

  const systemCats = categories.filter(c => c.is_system)
  const userCats = categories.filter(c => !c.is_system)

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0 }}>카테고리 관리</h2>
        <button onClick={() => setShowForm(true)} style={btnPrimaryStyle}>+ 카테고리 추가</button>
      </div>

      <CatSection title="내 카테고리" items={userCats} onDelete={handleDelete} />
      <CatSection title="시스템 카테고리" items={systemCats} onDelete={undefined} />

      {showForm && (
        <div style={overlayStyle} onClick={() => setShowForm(false)}>
          <div style={modalStyle} onClick={e => e.stopPropagation()}>
            <h3 style={{ margin: '0 0 1.5rem' }}>카테고리 추가</h3>
            <form onSubmit={handleSubmit(onSubmit)} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div>
                <label style={labelStyle}>이름</label>
                <input {...register('name', { required: true })} style={inputStyle} placeholder="카테고리 이름" />
              </div>
              <div>
                <label style={labelStyle}>유형</label>
                <select {...register('type', { required: true })} style={inputStyle}>
                  <option value="expense">지출</option>
                  <option value="income">수입</option>
                </select>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <label style={labelStyle}>아이콘 (이모지)</label>
                  <input {...register('icon')} style={inputStyle} placeholder="💰" />
                </div>
                <div>
                  <label style={labelStyle}>색상</label>
                  <input type="color" {...register('color')} style={{ ...inputStyle, padding: '0.3rem', height: 40 }} defaultValue="#6366f1" />
                </div>
              </div>
              <div style={{ display: 'flex', gap: '0.75rem', marginTop: '0.5rem' }}>
                <button type="submit" style={{ ...btnPrimaryStyle, flex: 1 }}>저장</button>
                <button type="button" onClick={() => setShowForm(false)} style={{ ...btnPrimaryStyle, flex: 1, background: '#e2e8f0', color: '#475569' }}>취소</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

function CatSection({ title, items, onDelete }: { title: string; items: Category[]; onDelete?: (id: string) => void }) {
  return (
    <div style={{ marginBottom: '2rem' }}>
      <h3 style={{ fontSize: '0.9rem', color: '#64748b', marginBottom: '0.75rem' }}>{title}</h3>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '0.75rem' }}>
        {items.length === 0 && <p style={{ color: '#94a3b8', fontSize: '0.875rem' }}>없음</p>}
        {items.map(c => (
          <div key={c.id} style={{ background: '#fff', borderRadius: 10, padding: '0.85rem 1rem', boxShadow: '0 1px 4px rgba(0,0,0,0.06)', display: 'flex', alignItems: 'center', gap: '0.6rem', borderLeft: `4px solid ${c.color ?? '#e2e8f0'}` }}>
            <span style={{ fontSize: '1.25rem' }}>{c.icon ?? '📦'}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ margin: 0, fontWeight: 600, fontSize: '0.875rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</p>
              <p style={{ margin: 0, fontSize: '0.75rem', color: '#94a3b8' }}>{c.type === 'income' ? '수입' : '지출'}</p>
            </div>
            {onDelete && (
              <button onClick={() => onDelete(c.id)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', fontSize: '1rem' }}>×</button>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

const btnPrimaryStyle: React.CSSProperties = { padding: '0.6rem 1.2rem', background: '#6366f1', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: '0.875rem' }
const overlayStyle: React.CSSProperties = { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }
const modalStyle: React.CSSProperties = { background: '#fff', borderRadius: 16, padding: '2rem', width: 400, boxShadow: '0 20px 60px rgba(0,0,0,0.2)' }
const labelStyle: React.CSSProperties = { display: 'block', fontSize: '0.8rem', fontWeight: 600, color: '#374151', marginBottom: '0.3rem' }
const inputStyle: React.CSSProperties = { width: '100%', padding: '0.6rem 0.75rem', border: '1px solid #d1d5db', borderRadius: 8, fontSize: '0.875rem', boxSizing: 'border-box' }
