# Rolume 官网

这是 Rolume 的静态官网子工程，使用 Astro、Markdown、Tailwind CSS 和 GitHub Pages。

## 每一部分是干什么的

- `astro.config.mjs`：Astro 配置，包含 Tailwind 插件和 GitHub Pages 的 `/Rolume` 路径。
- `src/layouts/BaseLayout.astro`：所有页面共用的 HTML 骨架，负责导航、SEO、页脚和全局样式。
- `src/pages/index.astro`：官网首页。改主视觉、下载按钮、功能区时主要改这里。
- `src/pages/*.md`：Markdown 内容页。FAQ、权限说明、更新记录这类文档页适合放这里。
- `src/data/site.ts`：产品链接、版本号、下载地址、功能文案等共享数据。
- `src/styles/global.css`：Tailwind 入口和少量全局 CSS。
- `public/`：原样复制到最终网站的静态文件，例如图标和 `.nojekyll`。
- `.github/workflows/pages.yml`：GitHub Actions 部署流程，推送后自动构建并发布到 GitHub Pages。

## 本地开发

```bash
cd website
npm install
npm run dev
```

然后打开 Astro 在终端里打印出来的本地地址。

## 生产构建

```bash
cd website
npm run build
npm run preview
```

## GitHub Pages 说明

当前默认配置假设仓库发布为 GitHub Pages 项目站：

```text
https://ericcilcn.github.io/Rolume/
```

如果之后使用自定义域名，需要更新 `astro.config.mjs`：

- 把 `site` 改成你的域名，例如 `https://rolume.app`。
- 删除 `base`，或者在部署环境设置 `SITE_BASE=/`。
- 添加 `website/public/CNAME`，里面只写域名本身。

## 如果你自己从零做一遍

1. 在仓库里创建 `website/`。
2. 初始化 Astro 项目，安装 Tailwind。
3. 把通用页面结构放到 `src/layouts/BaseLayout.astro`。
4. 把首页放到 `src/pages/index.astro`。
5. 把权限说明、FAQ、更新记录等内容写成 `src/pages/*.md`。
6. 把图标、favicon、`.nojekyll` 放到 `public/`。
7. 创建 `.github/workflows/pages.yml`，用 GitHub Actions 构建并部署。
8. 在 GitHub 仓库 Settings > Pages 中选择 GitHub Actions 作为发布来源。
