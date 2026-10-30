# Update CV on ReteInformaticaLavoro

Composite action that replaces the CV attached to a [reteinformaticalavoro.it](https://reteinformaticalavoro.it) candidate profile.

The website has no public API, so [`update_cv.py`](update_cv.py) sends the same plain HTTP requests as the browser (Python + `requests`, no browser automation):

1. `GET /login`, then `POST /login` with `_token`, `email`, `password`, `login_path`
2. `GET /candidati/curriculum` to get the CSRF token for the logged-in session
3. `GET /candidati/curriculum/load-cv?curriculum_id=0&is_company=0` to get the curriculum id
4. `POST /candidati/curriculum/documento?curriculum_id=<id>` with the file in the multipart field `Filedata`
5. `load-cv` again, failing if the stored file name didn't change

## Inputs

| Input | Required | Description |
| --- | :---: | --- |
| `email` | yes | Account email (store it as a secret) |
| `password` | yes | Account password (store it as a secret) |
| `cv-file` | yes | Path to the CV file to upload (PDF/DOC, max ~10 MB) |
| `base-url` | no | Website base URL (default: `https://reteinformaticalavoro.it`) |

## Outputs

| Output | Description |
| --- | --- |
| `curriculum-id` | Id of the candidate curriculum |
| `document-id` | Id of the newly uploaded document |
| `file-path` | Server-side path of the uploaded file |
| `file-date` | Upload timestamp reported by the website |

## Usage

```yaml
- uses: ./.github/actions/update-reteinformaticalavoro-cv
  with:
    email: ${{ secrets.RETEINFORMATICALAVORO_USERNAME }}
    password: ${{ secrets.RETEINFORMATICALAVORO_PASSWORD }}
    cv-file: build/lang/it/<your-cv>.pdf
```

In this repository it is run by the [`publish-reteinformaticalavoro.yml`](../../workflows/publish-reteinformaticalavoro.yml) workflow, which:

- runs after every successful **Release new CV version** run (uploading the CV from that release) and can also be started by hand (building the CV itself);
- uploads the CV in the language set by the `JOB_CV_LANG` environment variable (`it` by default);
- **fails** if either of these repository secrets is missing:
  - `RETEINFORMATICALAVORO_USERNAME`
  - `RETEINFORMATICALAVORO_PASSWORD`

## Running locally

The action is a self-contained [uv](https://docs.astral.sh/uv/) project (`pyproject.toml` + `uv.lock`). Every option can also be passed through its `RIL_*` environment variable (`RIL_EMAIL`, `RIL_PASSWORD`, `RIL_CV_FILE`, `RIL_BASE_URL`), which is the preferred way for the password:

```bash
RIL_PASSWORD=... uv run --project .github/actions/update-reteinformaticalavoro-cv \
  .github/actions/update-reteinformaticalavoro-cv/update_cv.py --email <email> --cv-file build/lang/it/<your-cv>.pdf
```
