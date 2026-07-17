import { api } from './client'
import type { AdminStats, AdminTransactionList, AdminUser, Category, CategoryAnalytics, TrendPoint } from '../types'

export const adminApi = {
  // 인증
  login: async (email: string, password: string) => {
    const form = new URLSearchParams({ username: email, password })
    const res = await api.post<{ access_token: string }>('/auth/login', form, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    })
    return res.data
  },
  me: async () => {
    const res = await api.get<{ email: string; is_superuser: boolean; full_name: string | null }>('/users/me')
    return res.data
  },

  // 통계
  stats: async () => {
    const res = await api.get<AdminStats>('/admin/stats')
    return res.data
  },

  // 사용자 관리
  users: async (params?: { skip?: number; limit?: number; search?: string; is_active?: boolean }) => {
    const res = await api.get<{ items: AdminUser[]; total: number }>('/admin/users', { params })
    return res.data
  },
  updateUser: async (id: string, data: { is_active?: boolean; is_superuser?: boolean }) => {
    const res = await api.patch(`/admin/users/${id}`, data)
    return res.data
  },
  deleteUser: async (id: string) => {
    await api.delete(`/admin/users/${id}`)
  },

  // 전체 거래 조회
  transactions: async (params?: { skip?: number; limit?: number; user_id?: string; type?: string }) => {
    const res = await api.get<AdminTransactionList>('/admin/transactions', { params })
    return res.data
  },
  deleteTransaction: async (id: string) => {
    await api.delete(`/admin/transactions/${id}`)
  },

  // 서비스 전체 분석
  analyticsTrends: async (months = 6) => {
    const res = await api.get<{ trends: TrendPoint[] }>('/admin/analytics/trends', { params: { months } })
    return res.data
  },
  analyticsByCategory: async (params: { year?: number; month?: number; type?: string }) => {
    const res = await api.get<CategoryAnalytics>('/admin/analytics/by-category', { params })
    return res.data
  },

  // 시스템 카테고리
  categories: async () => {
    const res = await api.get<Category[]>('/admin/categories')
    return res.data
  },
  createCategory: async (data: { name: string; type: string; icon?: string; color?: string }) => {
    const res = await api.post<Category>('/admin/categories', data)
    return res.data
  },
  updateCategory: async (id: string, data: { name?: string; icon?: string; color?: string }) => {
    const res = await api.patch<Category>(`/admin/categories/${id}`, data)
    return res.data
  },
  deleteCategory: async (id: string) => {
    await api.delete(`/admin/categories/${id}`)
  },
}
