import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: false,
    environment: "node",
    setupFiles: ["smoke/vitest.setup.ts"],
    include: ["src/**/*.test.ts", "smoke/**/*.test.ts"],
  },
});
