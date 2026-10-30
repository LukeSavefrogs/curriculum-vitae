# Curriculum Vitae

[![Static Badge](https://img.shields.io/badge/Powered_by-RenderCV-blue?label=%E2%9D%A4%EF%B8%8F%20Powered%20by&link=https%3A%2F%2Frendercv.com%2F)](https://rendercv.com/)

1. Install `uv`
2. Install dependencies: `uv sync`
3. Generate CV: `bash ./scripts/build_cv.sh`

## Publishing to job boards

The **Release new CV version** workflow can also upload the generated CV to job boards. The `JOB_CV_LANG` environment variable in [`release-cv.yml`](.github/workflows/release-cv.yml) selects which language is uploaded: it defaults to `it` at workflow level and can be overridden per job.

### ReteInformaticaLavoro

The [`update-reteinformaticalavoro-cv`](.github/actions/update-reteinformaticalavoro-cv) composite action replaces the CV attached to a [reteinformaticalavoro.it](https://reteinformaticalavoro.it) candidate profile, using plain HTTP requests (`curl` + `jq`, no browser automation).

The `update-reteinformaticalavoro` job runs only when both of these repository secrets are set:

- `RETEINFORMATICALAVORO_USERNAME`
- `RETEINFORMATICALAVORO_PASSWORD`

```yaml
- uses: ./.github/actions/update-reteinformaticalavoro-cv
  with:
    email: ${{ secrets.RETEINFORMATICALAVORO_USERNAME }}
    password: ${{ secrets.RETEINFORMATICALAVORO_PASSWORD }}
    cv-file: build/lang/it/<your-cv>.pdf
```
