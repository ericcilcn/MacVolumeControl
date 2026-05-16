import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

const site = process.env.SITE_URL ?? "https://ericcilcn.github.io";
const base = process.env.SITE_BASE ?? "/Rolume";

export default defineConfig({
  site,
  base,
  trailingSlash: "always",
  vite: {
    plugins: [tailwindcss()],
  },
});
