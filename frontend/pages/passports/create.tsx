import ProtectedRoute from '../../components/ProtectedRoute'
import MainApp from '../../components/MainApp'

export default function CreatePassportPageWrapper() {
  return (
    <ProtectedRoute>
      <MainApp />
    </ProtectedRoute>
  )
}