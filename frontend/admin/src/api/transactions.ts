import { apiClient } from './client'
import type { Transaction, TransactionCreate, TransactionListResponse } from '../types'

export interface TransactionFilter {
  skip?: number
  limit?: number
  type?: string
  category_id?: string
  start_date?: string
  end_date?: string
}

export const transactionsApi = {
  list: async (filter: TransactionFilter = {}) => {
    const res = await apiClient.get<TransactionListResponse>('/transactions/', { params: filter })
    return res.data
  },

  get: async (id: string) => {
    const res = await apiClient.get<Transaction>(`/transactions/${id}`)
    return res.data
  },

  create: async (data: TransactionCreate) => {
    const res = await apiClient.post<Transaction>('/transactions/', data)
    return res.data
  },

  update: async (id: string, data: Partial<TransactionCreate>) => {
    const res = await apiClient.patch<Transaction>(`/transactions/${id}`, data)
    return res.data
  },

  delete: async (id: string) => {
    await apiClient.delete(`/transactions/${id}`)
  },
}
