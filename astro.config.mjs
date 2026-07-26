// @ts-check
import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";
import { markdownConfig } from "@silitics/astro-theme/markdown";

export default defineConfig({
  site: "https://tascarrel.dev",
  server: {
    allowedHosts: true,
  },
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [mdx(), sitemap()],
  markdown: markdownConfig(),
});
