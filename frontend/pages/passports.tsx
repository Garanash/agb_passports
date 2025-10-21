import ProtectedRoute from '../components/ProtectedRoute'
import Layout from '../components/Layout'
import PassportsPage from './passports/index'

export default function PassportsPageWrapper() {
  return (
    <ProtectedRoute>
      <Layout>
        <PassportsPage />
      </Layout>
    </ProtectedRoute>
  )
}
