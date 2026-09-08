import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          'i18n-vendor': ['i18next', 'react-i18next'],
          'signalr-vendor': ['@microsoft/signalr'],
          'ui-vendor': ['lucide-react', 'react-easy-crop'],
          'http-vendor': ['axios'],
        },
      },
    },
  },
})
