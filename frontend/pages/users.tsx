import ProtectedRoute from '../components/ProtectedRoute'
import Layout from '../components/Layout'
import UsersPage from './users/index'

export default function UsersPageWrapper() {
  return (
    <ProtectedRoute>
      <Layout>
        <UsersPage />
      </Layout>
    </ProtectedRoute>
  )
}
