import { execFileSync } from "node:child_process";

function git(...args: string[]): string {
  return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
}

/**
 * Identifier of this build: "<CV_VERSION>#<short commit SHA>[-dirty]".
 *
 * Same format as `get_build_id` in `scripts/build_cv.sh` (shown on the PDF), so the website
 * and the PDF of a release show the same ID.
 */
function getBuildId(): string {
  const version = process.env.CV_VERSION || "dev";
  let commit: string;

  try {
    commit = git("rev-parse", "--short=7", "HEAD");
    if (git("status", "--porcelain", "--untracked-files=no") !== "") commit += "-dirty";
  } catch {
    commit = "unknown";
  }

  return `${version}#${commit}`;
}

export const buildId = getBuildId();
