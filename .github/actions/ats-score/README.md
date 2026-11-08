# ATS score

Composite action that scores a CV PDF with two free ATS checkers, both running offline on the runner:

| Checker | What it checks |
| --- | --- |
| [resume-parser-ats](https://www.npmjs.com/package/resume-parser-ats) | Parses the PDF the way an ATS does and grades what it could extract: name, email, phone, location, sections (`EXPERIENCE`, `EDUCATION`, `SKILLS`, …). Gives a score from 0 to 100, a grade (A+ to F) and the parsing issues it found. |
| [ats-check](https://github.com/hugounoclaw/ats-check) | Scores the text extracted from the PDF in seven categories: contact info, standard sections, parse-friendly formatting, action verbs, quantified impact, length, dates. Gives a score from 0 to 100 and a list of tips. |

[`ats-score.mjs`](ats-score.mjs) extracts the text with `pdf-parse` (the same library `resume-parser-ats` uses), runs both checkers and writes a Markdown report: a table with both scores, plus the issues and the per-category scores in a collapsible "Details" block.

A low score doesn't fail the step. An error does: unreadable PDF, no text in it, checker crash.

> [!NOTE]
> Both checkers only recognize English section names and action verbs, so non-English CVs get low scores for that reason alone.

## Inputs

| Input | Required | Description |
| --- | :---: | --- |
| `cv-file` | yes | Path to the CV PDF to score |

## Outputs

| Output | Description |
| --- | --- |
| `parser-score` | resume-parser-ats score (0-100) |
| `parser-grade` | resume-parser-ats grade (A+ to F) |
| `content-score` | ats-check score (0-100) |
| `report-file` | Path to the Markdown report |

## Usage

```yaml
- uses: ./.github/actions/ats-score
  id: ats
  with:
    cv-file: build/release/<your-cv>-en.pdf

- run: cat "${{ steps.ats.outputs.report-file }}" >> "$GITHUB_STEP_SUMMARY"
```

In this repository it is run by the [`ats-score.yml`](../../workflows/ats-score.yml) workflow, which:

- runs after every successful **Release new CV version** run, and can also be started by hand for any release (the `tag` input; the latest release by default);
- downloads the English PDF (`ATS_CV_LANG`) from the release assets, so it scores exactly the file that was released;
- replaces the placeholder between `<!-- ats-score:start -->` and `<!-- ats-score:end -->` in the release notes with the report (or appends it to releases that don't have one), so running it again updates the score instead of adding another one.

## Dependencies

The checkers are pinned in [`package.json`](package.json) and [`package-lock.json`](package-lock.json), so the score only changes when the CV or a checker version changes. Renovate opens the update PRs.

`ats-check` isn't published to npm, so it's installed from its GitHub tag.

## Running locally

```bash
npm ci --prefix .github/actions/ats-score
node .github/actions/ats-score/ats-score.mjs build/en/Luca_Salvarani_CV.pdf
```
