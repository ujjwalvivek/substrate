import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  base: "./",
  plugins: [svelte()],
  server: {
    port: 4321,
    strictPort: true,
    allowedHosts: ["datacenter", "datacenter.tail1db465.ts.net"],
  },
  preview: {
    port: 4321,
    strictPort: true,
  },
});
