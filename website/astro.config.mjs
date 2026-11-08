import { defineConfig } from "astro/config";

// On GitHub Pages these are set by the release workflow (from actions/configure-pages)
export default defineConfig({
  site: process.env.SITE_URL || undefined,
  base: process.env.BASE_PATH || "/",
  trailingSlash: "always",
});
