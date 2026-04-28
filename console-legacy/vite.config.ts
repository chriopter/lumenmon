import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [react()],
    root: './web/ui',
    base: '/app/',
    build: {
        outDir: '../public/app',
        emptyOutDir: true,
        sourcemap: false,
        rollupOptions: {
            output: {
                entryFileNames: 'main.js',
                chunkFileNames: 'chunks/[name].js',
                assetFileNames: (assetInfo) => {
                    if (assetInfo.name && assetInfo.name.endsWith('.css')) {
                        return 'main.css';
                    }
                    return 'assets/[name][extname]';
                }
            }
        }
    },
    server: {
        host: '0.0.0.0',
        port: 5173
    }
});
