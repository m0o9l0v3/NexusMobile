import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: "com.nexus.app",
  appName: "Nexus",
  webDir: "dist",
  server: process.env.CAP_DEV_SERVER_URL
    ? {
        url: process.env.CAP_DEV_SERVER_URL,
        cleartext: true,
      }
    : undefined,
};

export default config;
