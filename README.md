# Tascarrel Website

The landing page and documentation for
[Tascarrel](https://github.com/tascarrel/tascarrel), served at
<https://tascarrel.dev>. The site uses [Astro](https://astro.build) with the
[`@silitics/astro-theme`](https://www.npmjs.com/package/@silitics/astro-theme)
and
[`@silitics/astro-docs`](https://www.npmjs.com/package/@silitics/astro-docs)
packages.

## Local Development

```sh
pnpm install
pnpm dev
```

The site runs at <http://127.0.0.1:4325>.

## Build

```sh
pnpm build
```

The static site is generated in `dist/`. The build also renders the repository
root `install.sh` as `dist/install.sh`, which makes it available at
<https://tascarrel.dev/install.sh> when the site is deployed.

## Content Layout

- `src/pages/index.astro` contains the landing page.
- `src/content/docs/` contains the Markdown documentation.
- `src/site.ts` defines navigation, footer links, and documentation structure.
- `install.sh` is the source for the installer served at `/install.sh`.
