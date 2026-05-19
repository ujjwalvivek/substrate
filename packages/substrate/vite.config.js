import { defineConfig } from "vite";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageRoot = fileURLToPath(new URL(".", import.meta.url));

export default defineConfig({
  build: {
    lib: {
      entry: {
        index: resolve(packageRoot, "src/engine/index.js"),
        cpu: resolve(packageRoot, "src/engine/cpu.js"),
        colors: resolve(packageRoot, "src/engine/colors.js"),
        theme: resolve(packageRoot, "src/engine/theme.js"),
        core: resolve(packageRoot, "src/engine/core.js"),
      },
      formats: ["es"],
      fileName: (_format, entryName) => `${entryName}.js`,
    },
  },
});
