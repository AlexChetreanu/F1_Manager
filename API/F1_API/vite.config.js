import { defineConfig, loadEnv } from 'vite'
import laravel from 'laravel-vite-plugin'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const APP_URL = env.APP_URL || 'http://172.20.10.10:8000'
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
        host: 'localhost',
      },
    },
    define: {
      __APP_URL__: JSON.stringify(APP_URL),
    },
  }
})
