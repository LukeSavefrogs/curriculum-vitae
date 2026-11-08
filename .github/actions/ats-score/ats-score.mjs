#!/usr/bin/env node
/**
 * Scores a CV PDF with two free, offline ATS checkers and prints a Markdown report:
 *
 * - resume-parser-ats: parses the PDF the way an ATS does (name, contact details, sections)
 *   and grades how much of it could be extracted;
 * - ats-check: scores the extracted text (contact info, section names, formatting, action
 *   verbs, numbers, length, dates).
 *
 * Usage: node ats-score.mjs <cv.pdf> [--report <report.md>]
 *
 * Low scores are not errors. In GitHub Actions the scores and the report path are also
 * written to $GITHUB_OUTPUT.
 */
import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { parseArgs } from "node:util";

import { analyze as checkContent } from "ats-check";

const require = createRequire(import.meta.url);
const { analyzeResume, parseResumeAsync } = require("resume-parser-ats");
// The package entry point runs a self-test when it thinks it is the main module, so load the library itself
const pdfParse = require("pdf-parse/lib/pdf-parse.js");

const pkg = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf8"));

const SEVERITY_ORDER = ["critical", "high", "medium", "low"];
const TIP_SEVERITY = { hi: "high", me: "medium", lo: "low" };

function fail(message) {
  console.error(process.env.GITHUB_ACTIONS ? `::error title=ATS score::${message}` : `Error: ${message}`);
  process.exit(1);
}

/** Version shown in the report: the git ref for GitHub dependencies, the installed version otherwise. */
function checkerVersion(name) {
  const ref = pkg.dependencies[name].split("#")[1];
  if (ref) return /^[0-9a-f]{40}$/.test(ref) ? ref.slice(0, 7) : ref;
  return require(`${name}/package.json`).version;
}

const cell = (text) => String(text).replaceAll("|", "\\|").replaceAll("\n", " ");

function renderReport({ parser, content }) {
  const issues = [...parser.formatIssues].sort(
    (a, b) => SEVERITY_ORDER.indexOf(a.severity) - SEVERITY_ORDER.indexOf(b.severity),
  );
  const tips = content.cats.flatMap((cat) => cat.tips.map((tip) => ({ ...tip, category: cat.key })));

  return [
    "| Checker | What it checks | Score |",
    "| --- | --- | :---: |",
    `| [resume-parser-ats](https://www.npmjs.com/package/resume-parser-ats) \`${checkerVersion("resume-parser-ats")}\` ` +
      `| What an ATS parser extracts from the PDF: name, contact details, sections | **${parser.atsScore}**/100 (${parser.atsGrade}) |`,
    `| [ats-check](https://github.com/hugounoclaw/ats-check) \`${checkerVersion("ats-check")}\` ` +
      `| The text: contact info, section names, formatting, action verbs, numbers, length, dates | **${content.total}**/100 |`,
    "",
    "<details>",
    "<summary>Details</summary>",
    "",
    "**resume-parser-ats** issues:",
    "",
    ...(issues.length ? issues.map((i) => `- ${i.severity}: ${i.description}`) : ["- none"]),
    "",
    `**ats-check** categories (${content.wc} words):`,
    "",
    "| Category | Score |",
    "| --- | :---: |",
    ...content.cats.map((cat) => `| ${cell(cat.key)} | ${cat.score}/${cat.max} |`),
    "",
    "**ats-check** tips:",
    "",
    ...(tips.length ? tips.map((t) => `- ${TIP_SEVERITY[t.p] ?? t.p}: ${t.t}`) : ["- none"]),
    "",
    "</details>",
    "",
  ].join("\n");
}

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: { report: { type: "string" } },
});
if (positionals.length !== 1) {
  console.error("Usage: node ats-score.mjs <cv.pdf> [--report <report.md>]");
  process.exit(2);
}
const [cvFile] = positionals;

let text;
try {
  ({ text } = await pdfParse(readFileSync(cvFile)));
} catch (error) {
  fail(`Cannot read text from ${cvFile}: ${error.message}`);
}
if (!text.trim()) fail(`No text could be extracted from ${cvFile}`);

const parsed = await parseResumeAsync({ filePath: cvFile });
if (!parsed.success) fail(`resume-parser-ats could not parse ${cvFile}: ${parsed.metadata.warnings.join("; ")}`);
const analysis = analyzeResume({ filePath: cvFile, parsedResume: parsed.data, strictness: "moderate" });
if (!analysis.success) fail(`resume-parser-ats could not analyze ${cvFile}`);

const parser = analysis.data;
const content = checkContent(text);
const report = renderReport({ parser, content });

process.stdout.write(report);
if (values.report) writeFileSync(values.report, report);

if (process.env.GITHUB_OUTPUT) {
  appendFileSync(
    process.env.GITHUB_OUTPUT,
    [
      `parser-score=${parser.atsScore}`,
      `parser-grade=${parser.atsGrade}`,
      `content-score=${content.total}`,
      ...(values.report ? [`report-file=${values.report}`] : []),
      "",
    ].join("\n"),
  );
}
