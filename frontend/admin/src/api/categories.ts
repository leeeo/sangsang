import { apiClient } from './client'
import type { Category } from '../types'

export const categoriesApi = {
  list: async () => {
    const res = await apiClient.get<Category[]>('/categories/')
    return res.data
  },

  create: async (data: { name: string; type: string; icon?: string; color?: string }) => {
    const res = await apiClient.post<Category>('/categories/', data)
    return res.data
  },

  update: async (id: string, data: { name?: string; icon?: string; color?: string }) => {
    const res = await apiClient.patch<Category>(`/categories/${id}`, data)
    return res.data
  },

  delete: async (id: string) => {
    await apiClient.delete(`/categories/${id}`)
  },
}
