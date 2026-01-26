import React from 'react'
import Layout from '../components/Layout'
import StickerTemplateEditor from '../components/StickerTemplateEditor'
import ProtectedRoute from '../components/ProtectedRoute'

export default function StickerTemplateEditorPage() {
  return (
    <ProtectedRoute>
      <Layout>
        <StickerTemplateEditor />
      </Layout>
    </ProtectedRoute>
  )
}
