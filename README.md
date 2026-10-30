# Curriculum Vitae

[![Static Badge](https://img.shields.io/badge/Powered_by-RenderCV-blue?label=%E2%9D%A4%EF%B8%8F%20Powered%20by&link=https%3A%2F%2Frendercv.com%2F)](https://rendercv.com/)

1. Install `uv`
2. Install dependencies: `uv sync`
3. Generate CV: `bash ./scripts/build_cv.sh`

## Publishing to job boards

| Job board | Link | Deploy status |
| --- | :---: | --- |
| ReteInformaticaLavoro | [Website Homepage](https://reteinformaticalavoro.it)<br/><br/><sub><i>(no public profile page)</i></sub> | [![Publish CV to ReteInformaticaLavoro](https://github.com/LukeSavefrogs/curriculum-vitae/actions/workflows/publish-reteinformaticalavoro.yml/badge.svg)](https://github.com/LukeSavefrogs/curriculum-vitae/actions/workflows/publish-reteinformaticalavoro.yml) |

Each job board has its own `publish-<job-board>.yml` workflow, which runs after every successful **Release new CV version** run (uploading the CV from that release) and can also be started by hand (building the CV itself). The `JOB_CV_LANG` environment variable in each of these workflows selects which language is uploaded: it defaults to `it` at workflow level and can be overridden per job.

### ReteInformaticaLavoro

The [`update-reteinformaticalavoro-cv`](.github/actions/update-reteinformaticalavoro-cv) composite action replaces the CV attached to a [reteinformaticalavoro.it](https://reteinformaticalavoro.it) candidate profile, using plain HTTP requests (Python + `requests`, no browser automation). It is a self-contained [uv](https://docs.astral.sh/uv/) project (`pyproject.toml` + `uv.lock`), so it can also be run locally:

```bash
RIL_PASSWORD=... uv run --project .github/actions/update-reteinformaticalavoro-cv \
  .github/actions/update-reteinformaticalavoro-cv/update_cv.py --email <email> --cv-file build/lang/it/<your-cv>.pdf
```

The [`publish-reteinformaticalavoro.yml`](.github/workflows/publish-reteinformaticalavoro.yml) workflow uploads the CV only when both of these repository secrets are set:

- `RETEINFORMATICALAVORO_USERNAME`
- `RETEINFORMATICALAVORO_PASSWORD`

```yaml
- uses: ./.github/actions/update-reteinformaticalavoro-cv
  with:
    email: ${{ secrets.RETEINFORMATICALAVORO_USERNAME }}
    password: ${{ secrets.RETEINFORMATICALAVORO_PASSWORD }}
    cv-file: build/lang/it/<your-cv>.pdf
```
