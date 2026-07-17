import { apiClient } from './client'
import type { User } from '../types'

export const authApi = {
  login: async (email: string, password: string) => {
    const form = new URLSearchParams()
    form.append('username', email)
    form.append('password', password)
    const res = await apiClient.post<{ access_token: string; token_type: string }>(
      '/auth/login',
      form,
      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    )
    return res.data
  },

  register: async (data: {
    email: string
    username: string
    password: string
    full_name?: string
  }) => {
    const res = await apiClient.post<User>('/auth/register', data)
    return res.data
  },

  me: async () => {
    const res = await apiClient.get<User>('/users/me')
    return res.data
  },
}
