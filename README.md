# Curriculum Vitae

[![Static Badge](https://img.shields.io/badge/Powered_by-RenderCV-blue?label=%E2%9D%A4%EF%B8%8F%20Powered%20by&link=https%3A%2F%2Frendercv.com%2F)](https://rendercv.com/)

1. Install `uv`
2. Install dependencies: `uv sync`
3. Generate CV: `bash ./scripts/build_cv.sh`

## Publishing to job boards

The [`update-reteinformaticalavoro-cv`](.github/actions/update-reteinformaticalavoro-cv) composite action replaces the CV attached to a [reteinformaticalavoro.it](https://reteinformaticalavoro.it) candidate profile, using plain HTTP requests (`curl` + `jq`, no browser automation).

It runs as part of the **Release new CV version** workflow (uploading the Italian PDF) when these repository secrets are set:

- `RETEINFORMATICALAVORO_EMAIL`
- `RETEINFORMATICALAVORO_PASSWORD`

```yaml
- uses: ./.github/actions/update-reteinformaticalavoro-cv
  with:
    email: ${{ secrets.RETEINFORMATICALAVORO_EMAIL }}
    password: ${{ secrets.RETEINFORMATICALAVORO_PASSWORD }}
    cv-file: build/it/<your-cv>.pdf
```
