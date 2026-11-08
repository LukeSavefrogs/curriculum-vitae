# CLAUDE.md

Notes for Claude sessions working on this repository, collected from past sessions.

## What this repo is

- The CV of Luca Salvarani, built with [RenderCV](https://rendercv.com/).
- `cv-en.yaml` and `cv-it.yaml` are the single source of truth: one file per language, named `cv-<lang>.yaml`.
  - RenderCV builds the PDF, PNG, Markdown and HTML from them.
  - The Astro website in `website/` renders the same files.
  - Section keys are localized (`experience` / `esperienze`, …) and rendered as Title Case. Entry types are inferred from their fields, the RenderCV way.
- RenderCV configuration is in `config/design.yaml` and `config/rendercv.settings.yaml`.
- Output goes to `build/<lang>/Luca_Salvarani_CV.{pdf,png,md,html,typ}` and is gitignored.

## Commands

```bash
uv sync                                    # Python >= 3.14, rendercv[full]
./scripts/build_cv.sh --no-tmux            # build all languages
CV_VERSION=cv-test ./scripts/build_cv.sh --no-tmux   # release-style build ID
./scripts/build_cv.sh --no-tmux -- -nopng -nomd      # extra options are passed to RenderCV
./scripts/build_cv.sh -w                   # watch mode (tmux if available)

cd website && npm ci && npm run dev        # or: npm run build / npm run preview
```

- Linting: `uvx --from shellcheck-py shellcheck --severity=warning scripts/build_cv.sh`, `actionlint`. For the website, `npx astro check` (install `@astrojs/check` and `typescript` with `--no-save`).
- There are no tests, and no workflow runs on pull requests, so verify by building locally.

## Working with the user

- **Plan first** and get the plan approved before changing anything. "Only plan" means: do not commit.
- **Commits:** Conventional Commits (`feat:`, `fix:`, `ci:`, `docs:`, `style:`, `chore(deps):`), with short, focused messages. Reference issues with `Closes #N`.
- **Branches and PRs:**
  - Work on a branch and don't open a PR unless asked.
  - When working on an issue, push to a new branch and open the PR at the end.
  - Once a PR is merged, restart the branch from `main` instead of stacking new commits on merged history.
- **Patches:** when applying a patch with `git am`, keep the original commits. Don't squash or reword them. If it fails, stop and explain why.
- **No scheduled follow-ups:** don't schedule check-ins or reminders on your own.
- **Screenshots:** never commit screenshots or other binaries to the repo. Send them in the chat.
- **Visual proof:** after a test build, send screenshots of the result.
  - The user often asks for the whole page, the mobile layout (iPhone 13), viewport-only shots, and side-by-side before/after comparisons.
  - Chat images are capped at 8000 px, so split tall full-page screenshots into parts.
  - Send the built files themselves when asked.
- **Website design:** minimal. No hero, no emojis, no "hacker"/terminal look.
- **READMEs:**
  - Keep the main README short and put component details in a README next to the component (e.g. the job-board action).
  - Keep the job-board table in the main README in its current format.
- **Workflows:** fail loudly instead of succeeding silently, so status badges stay truthful.

## Build ID (versioning)

- Format: `<version>#<commit>[-dirty]`, for example `cv-2026.11.08-09.34.25#b65f2f5` or `dev#0d0cfaa`.
  - `<version>` is `CV_VERSION`, or `dev` if unset.
  - `<commit>` is `git rev-parse --short=7 HEAD`.
  - `-dirty` is added if `git status --porcelain --untracked-files=no` prints anything, so untracked files never mark a build as dirty.
- On release, the `version` job in `.github/workflows/release-cv.yml` creates the tag (`cv-%Y.%m.%d-%H.%M.%S`) and passes it:
  - to `generate-cv.yml` through its `cv-version` input;
  - to the website build as `CV_VERSION`.

  This way the PDF, the release and the website show the same ID.
- Where it's shown:
  - **PDF:** the top-right note (`--design.templates.top_note`). It has localized labels (`Version` / `Versione`) and a link to `/releases/latest`; the link URL is built from `GITHUB_SERVER_URL`/`GITHUB_REPOSITORY`, so forks link to themselves.
  - **Website:** the footer, centered, with no label.
- `website/src/lib/build.ts` mirrors `get_build_id` in `scripts/build_cv.sh`. Keep the two in sync.

## Website (`website/`)

- Astro static site (Node >= 22.23.4). It loads `../cv-*.yaml` with `import.meta.glob` and parses them with `yaml`.
  - There is one page per language (`/en/`, `/it/`), and `/` redirects to `/en/`.
  - Inline Markdown in the YAML is rendered with `marked.parseInline`.
- `src/lib/cv.ts` holds the data loading, the per-language labels and the date formatting (`Intl`).
- `src/components/Entry.astro` renders any RenderCV entry type.
- `src/layouts/Base.astro` holds all the CSS: colour variables with a dark-mode variant, a single column, the system font.
- Use a 301 for the redirect: in static builds `Astro.redirect` with a 302 writes a meta refresh with a 2 s delay.
- `site`/`base` come from the `SITE_URL`/`BASE_PATH` env vars, which `actions/configure-pages` provides in CI. `trailingSlash: "always"` is set. Build every internal link with the `url()` helper so it works under `/curriculum-vitae/`.
- Astro minifies the HTML, so inline `<li>`s have no whitespace between them and never wrap. Use `display: flex; flex-wrap: wrap` for inline lists.
- "Download PDF" links to `releases/latest/download/Luca_Salvarani_CV-<lang>.pdf`. That asset name comes from the rename step of `create-release`.
- Deployment: the `gh-pages` job in `release-cv.yml`. It runs only on release, after `create-release`, so the "latest" PDF link already points to the new CV.

## RenderCV / Typst gotchas

- A `#` followed by a letter in text (e.g. `cv-x#abc1234`) is read as Typst code and the build fails with `unknown variable`. Wrap such text in backticks, which renders it as raw (monospace) text.
- Uppercase placeholder words in templates are replaced, so keep them out of literal text: `NAME`, `YEAR`, `CURRENT_DATE`, `LAST_UPDATED`, `PAGE_NUMBER`, `TOTAL_PAGES`, …
- The top note only appears in the PDF and PNG, not in the Markdown or HTML.
- A template placed next to the YAML (e.g. `markdown/Header.j2.md`) overrides RenderCV's built-in one.
- The `cv:` section forbids extra keys.
- Compiling the PDF downloads Typst packages from `packages.typst.org`, so that host must be reachable.

## CI and job boards

- Workflows:
  - `generate-cv.yml` builds the CV and uploads it as the `generated-cv` artifact.
  - `release-cv.yml` is manual. Its jobs are `version`, `generate-cv`, `create-release` and `gh-pages`.
  - `ats-score.yml` runs after each release (or by hand, with an optional `tag`). See "ATS score" below.
- ReteInformaticaLavoro upload:
  - `publish-reteinformaticalavoro.yml` is a separate workflow so it gets its own run history and badge.
  - It's triggered by `workflow_run`, which only fires from workflows on the default branch, or by a manual run, which builds the CV itself.
  - It uploads the `it` CV (`JOB_CV_LANG`).
  - It fails if the `RETEINFORMATICALAVORO_USERNAME` or `RETEINFORMATICALAVORO_PASSWORD` secrets are missing.
- `secrets.*` and `env.*` can't be used in a job-level `if:`. Check them in a step of a separate job and gate on that job's result.
- `.github/actions/update-reteinformaticalavoro-cv/` is a self-contained uv project (Python + `requests`, its own `uv.lock`). The site has no API, so the action replays the browser's HTTP requests (a Laravel site with CSRF tokens). Its README has the details.
- To add a job board: create a `publish-<board>.yml` workflow and a composite action under `.github/actions/`, then add a row to the README table.
- Big boards (LinkedIn, Indeed, Glassdoor) forbid automated access and use CAPTCHAs or 2FA, so don't automate them.
- Renovate and Dependabot regularly bump uv, `astral-sh/setup-uv`, Python, npm packages and the devcontainer features.

## ATS score

- `ats-score.yml` scores the `en` PDF (`ATS_CV_LANG`) downloaded from the release assets with `.github/actions/ats-score/`, a self-contained Node project (`package-lock.json`) that runs two free, offline checkers:
  - `resume-parser-ats` (npm) parses the PDF like an ATS: score, grade and parsing issues.
  - `ats-check` scores the text extracted with `pdf-parse`. It isn't on npm, so it's a GitHub dependency pinned to a tag.
- Both checkers only know English section names and action verbs, so the `it` CV isn't checked (it scored 46/D and 55 only because of that).
- The report replaces the text between `<!-- ats-score:start -->` and `<!-- ats-score:end -->` in the release notes. `release-cv.yml` puts a placeholder there; older releases get the section appended. Reruns update it in place.
- A low score never fails the workflow; errors do.
- To find the release created by the triggering run, it compares the latest release's `publishedAt` with the run's `run_started_at`. Don't use `createdAt`: for releases it's the date of the commit.
- Known findings (en, Nov 2026): 84/100 (A-) and 92/100. The header icons end up in the PDF text as private-use characters, so the contact details are merged into one line and the phone number isn't detected.

## Claude cloud environment

- The "curriculum-vitae" environment allows `packages.typst.org`.
- Its setup script runs `uv sync --locked` with retries, because GitHub sometimes returns 504 while uv downloads Python.
- uv prints a `UV_NATIVE_TLS … deprecated` warning on every call. It's harmless.
- The GitHub API can't upload images to PR descriptions. The user has to drag them into the PR on GitHub.
