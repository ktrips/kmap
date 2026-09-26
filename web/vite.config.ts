import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        // React・Firebaseをアプリ本体と別チャンクに分けることで、
        // アプリのコードだけを更新した時にブラウザがこの大きな依存関係を
        // 再ダウンロードせずキャッシュを使い回せるようにする。
        manualChunks(id) {
          if (id.includes('node_modules/react') || id.includes('node_modules/scheduler')) {
            return 'react'
          }
          // Analytics・Cloud Functionsは動的importで必要になった時だけ読み込むため、
          // 共通のfirebaseチャンクに入れない（入れると初回表示で一緒に読み込まれてしまう）。
          if (/node_modules\/(@firebase\/(analytics|functions|installations)|firebase\/(analytics|functions))/.test(id)) {
            return undefined
          }
          if (id.includes('node_modules/firebase') || id.includes('node_modules/@firebase')) {
            return 'firebase'
          }
        },
      },
    },
  },
})
