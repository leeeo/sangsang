export interface User {
  id: string
  email: string
  username: string
  full_name: string | null
  phone: string | null
  is_active: boolean
  created_at: string
}

export type TransactionType = 'income' | 'expense'

export interface Transaction {
  id: string
  user_id: string
  category_id: string
  amount: string
  type: TransactionType
  transaction_date: string
  counterparty_name: string | null
  memo: string | null
  event_type: string | null
  created_at: string
}

export interface TransactionListResponse {
  items: Transaction[]
  total: number
  skip: number
  limit: number
}

export interface TransactionCreate {
  category_id: string
  amount: number
  type: TransactionType
  transaction_date: string
  counterparty_name?: string
  memo?: string
  event_type?: string
}

export interface Category {
  id: string
  name: string
  type: 'income' | 'expense' | 'transfer'
  icon: string | null
  color: string | null
  is_system: boolean
  parent_id: string | null
}

export interface AnalyticsSummary {
  year: number
  month: number
  income: number
  expense: number
  balance: number
  income_count: number
  expense_count: number
}

export interface TrendItem {
  year: number
  month: number
  income: number
  expense: number
}

export interface CategoryStat {
  id: string
  name: string
  color: string | null
  total: number
  count: number
  ratio: number
}
