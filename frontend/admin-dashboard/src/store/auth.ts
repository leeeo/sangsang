import { create } from 'zustand'
import { adminApi } from '../api/admin'

interface AuthState {
  user: { email: string; is_superuser: boolean; full_name: string | null } | null
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  fetchMe: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  isLoading: false,

  login: async (email, password) => {
    set({ isLoading: true })
    try {
      const { access_token } = await adminApi.login(email, password)
      localStorage.setItem('admin_token', access_token)
      const me = await adminApi.me()
      if (!me.is_superuser) {
        localStorage.removeItem('admin_token')
        throw new Error('관리자 계정이 아닙니다')
      }
      set({ user: me })
    } finally {
      set({ isLoading: false })
    }
  },

  logout: () => {
    localStorage.removeItem('admin_token')
    set({ user: null })
    window.location.href = '/login'
  },

  fetchMe: async () => {
    if (!localStorage.getItem('admin_token')) return
    try {
      const me = await adminApi.me()
      if (!me.is_superuser) {
        localStorage.removeItem('admin_token')
        return
      }
      set({ user: me })
    } catch {
      localStorage.removeItem('admin_token')
    }
  },
}))
