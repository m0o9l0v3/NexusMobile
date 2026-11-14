import { defineConfig } from "vite";
import path from "path";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";

// 公開サイトはトップ＋3ページのマルチページ構成（#131）。ルーター用のライブラリは使わない。
const page = (name) => path.resolve(__dirname, name);

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: "0.0.0.0",
    port: 5176,
    strictPort: true,
  },
  build: {
    rollupOptions: {
      input: {
        top: page("index.html"),
        development: page("development/index.html"),
        status: page("status/index.html"),
        tech: page("tech/index.html"),
      },
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
