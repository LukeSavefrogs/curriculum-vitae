# Curriculum Vitae

[![Static Badge](https://img.shields.io/badge/Powered_by-RenderCV-blue?label=%E2%9D%A4%EF%B8%8F%20Powered%20by&link=https%3A%2F%2Frendercv.com%2F)](https://rendercv.com/)

1. Install `uv`
2. Install dependencies: `uv sync`
3. Generate CV: `bash ./scripts/build_cv.sh`

## Website

The [`website/`](website/) folder contains a minimal [Astro](https://astro.build/) site that renders the same `cv-*.yaml` files (one page per language).

```bash
cd website
npm ci
npm run dev    # or: npm run build
```

It is built and deployed to GitHub Pages by the [release workflow](.github/workflows/release-cv.yml), after the release is created, so its "Download PDF" link always points to the latest CV.

## Versioning

The top-right corner of every PDF shows the CV build ID and a link to the [latest release](https://github.com/LukeSavefrogs/curriculum-vitae/releases/latest), so it's always possible to tell exactly which CV was sent and whether a newer one exists.

The same build ID is shown in the footer of the [website](#website).

The build ID has the format `<version>#<commit>`:

- `<version>` is the release tag (e.g. `cv-2025.01.31-10.00.00`) for CVs built by the [release workflow](.github/workflows/release-cv.yml), or `dev` for any other build. It can be overridden with the `CV_VERSION` environment variable (e.g. `CV_VERSION=test bash ./scripts/build_cv.sh`);
- `<commit>` is the short SHA of the commit the CV was generated from, with a `-dirty` suffix if tracked files had uncommitted changes.

## Publishing to job boards

| Job board | Link | Deploy status |
| --- | :---: | --- |
| ReteInformaticaLavoro | [Website Homepage](https://reteinformaticalavoro.it)<br/><sub><i>(no public profile page)</i></sub> | [![Publish CV to ReteInformaticaLavoro](https://github.com/LukeSavefrogs/curriculum-vitae/actions/workflows/publish-reteinformaticalavoro.yml/badge.svg)](https://github.com/LukeSavefrogs/curriculum-vitae/actions/workflows/publish-reteinformaticalavoro.yml) |

The CV is automatically updated on these job boards with each new release (_implementation details are in each job board's action_).
