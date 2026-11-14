/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** public-api の URL（例：https://api.example.jp）。`/health` の死活表示だけに使う（#131）。 */
  readonly VITE_API_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
