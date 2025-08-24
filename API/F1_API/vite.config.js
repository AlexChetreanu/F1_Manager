import { defineConfig, loadEnv } from 'vite'
import laravel from 'laravel-vite-plugin'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const host = env.VITE_DEV_HOST || 'MacBook-Pro-Alexandru.local'
  const APP_URL = env.APP_URL || `http://${host}:8000`
  const API_BASE_URL = env.VITE_API_BASE_URL || APP_URL
  return {
    plugins: [
      laravel({
        input: ['resources/css/app.css', 'resources/js/app.js'],
        refresh: true,
      }),
    ],
    server: {
      host: true,
      port: 5173,
      strictPort: true,
      hmr: {
        host,
      },
    },
    define: {
      __APP_URL__: JSON.stringify(APP_URL),
      __API_BASE_URL__: JSON.stringify(API_BASE_URL),
    },
  }
})
