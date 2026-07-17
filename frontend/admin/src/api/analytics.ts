import { apiClient } from './client'
import type { AnalyticsSummary, CategoryStat, TrendItem } from '../types'

export const analyticsApi = {
  summary: async (year?: number, month?: number) => {
    const res = await apiClient.get<AnalyticsSummary>('/analytics/summary', {
      params: { year, month },
    })
    return res.data
  },

  trends: async (months = 6) => {
    const res = await apiClient.get<{ trends: TrendItem[] }>('/analytics/trends', {
      params: { months },
    })
    return res.data.trends
  },

  byCategory: async (type: 'income' | 'expense' = 'expense', year?: number, month?: number) => {
    const res = await apiClient.get<{ categories: CategoryStat[]; total: number }>(
      '/analytics/by-category',
      { params: { type, year, month } }
    )
    return res.data
  },
}
