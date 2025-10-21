import ProtectedRoute from '../../components/ProtectedRoute'
import Layout from '../../components/Layout'
import SimplePassportForm from '../../components/SimplePassportForm'

export default function CreatePassportPageWrapper() {
  return (
    <ProtectedRoute>
      <Layout>
        <SimplePassportForm />
      </Layout>
    </ProtectedRoute>
  )
}