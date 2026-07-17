export interface AdminUser {
  id: string
  email: string
  username: string
  full_name: string | null
  is_active: boolean
  is_superuser: boolean
  created_at: string
  tx_count: number
}

export interface AdminStats {
  users: { total: number; active: number; inactive: number }
  transactions: {
    income_count: number
    income_total: number
    expense_count: number
    expense_total: number
  }
  monthly_signups: { year: number; month: number; count: number }[]
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

export interface AdminTransaction {
  id: string
  user_id: string
  amount: string
  type: 'income' | 'expense'
  transaction_date: string
  counterparty_name: string | null
  memo: string | null
  event_type: string | null
}

export interface AdminTransactionList {
  items: AdminTransaction[]
  total: number
}

export interface TrendPoint {
  year: number
  month: number
  income: number
  expense: number
  income_count: number
  expense_count: number
}

export interface CategoryStat {
  id: string
  name: string
  color: string | null
  total: number
  count: number
  ratio: number
}

export interface CategoryAnalytics {
  year: number
  month: number
  type: string
  total: number
  categories: CategoryStat[]
}
