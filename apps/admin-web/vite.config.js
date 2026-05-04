import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const projectDir = dirname(fileURLToPath(import.meta.url));
export default defineConfig({
    plugins: [react(), tailwindcss()],
    resolve: {
        alias: {
            react: resolve(projectDir, '../../node_modules/react'),
            'react/jsx-runtime': resolve(projectDir, '../../node_modules/react/jsx-runtime.js'),
            'react/jsx-dev-runtime': resolve(projectDir, '../../node_modules/react/jsx-dev-runtime.js'),
            'react-dom': resolve(projectDir, '../../node_modules/react-dom'),
            'react-dom/client': resolve(projectDir, '../../node_modules/react-dom/client.js'),
        },
        dedupe: ['react', 'react-dom'],
    },
    optimizeDeps: {
        include: ['react', 'react-dom', 'react-dom/client'],
    },
    server: {
        port: 5179,
    },
});
