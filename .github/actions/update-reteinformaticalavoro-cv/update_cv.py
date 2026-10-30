"""Replace the CV document attached to a candidate profile on https://reteinformaticalavoro.it

The website exposes no public API, so this script reproduces what the browser does:
  1. GET  /login                         -> session + CSRF token
  2. POST /login                         -> authenticated session
  3. GET  /candidati/curriculum          -> fresh CSRF token
  4. GET  /candidati/curriculum/load-cv  -> curriculum id (JSON)
  5. POST /candidati/curriculum/documento?curriculum_id=<id>
          multipart field `Filedata`     -> upload (uploadifive)
  6. GET  /candidati/curriculum/load-cv  -> verify the new file

Every option can also be passed through its `RIL_*` environment variable, which is the
preferred way for the password (command line arguments are visible to other processes).
"""

import argparse
import json
import logging
import os
import re
import sys
from pathlib import Path

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

DEFAULT_BASE_URL = "https://reteinformaticalavoro.it"
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36"
)
MAX_SIZE_BYTES = 10_000 * 1024  # uploadifive `fileSizeLimit: 1e4` (KB)
TIMEOUT_SECONDS = 60

# Laravel exposes the CSRF token either as `<meta name="csrf-token">` or `<input name="_token">`
CSRF_PATTERNS = (
    re.compile(r'<meta name="csrf-token" content="([^"]+)"'),
    re.compile(r'name="_token" value="([^"]+)"'),
)
# The page `eval`s the upload response, so it may be a JS object literal rather than strict JSON
SRC_PATTERN = re.compile(r"""["']?src["']?\s*:\s*["']([^"']+)""")

log = logging.getLogger("reteinformaticalavoro")


class UpdateError(Exception):
    """Expected failure, reported without a traceback."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Replace the CV attached to a reteinformaticalavoro.it candidate profile.",
    )
    parser.add_argument(
        "--email",
        default=os.environ.get("RIL_EMAIL"),
        help="Account email (env: RIL_EMAIL)",
    )
    parser.add_argument(
        "--password",
        default=os.environ.get("RIL_PASSWORD"),
        help="Account password (env: RIL_PASSWORD)",
    )
    parser.add_argument(
        "--cv-file",
        type=Path,
        default=os.environ.get("RIL_CV_FILE"),
        help="Path to the CV file to upload (env: RIL_CV_FILE)",
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("RIL_BASE_URL") or DEFAULT_BASE_URL,
        help=f"Website base URL (env: RIL_BASE_URL, default: {DEFAULT_BASE_URL})",
    )
    args = parser.parse_args()

    for name in ("email", "password", "cv_file"):
        if not getattr(args, name):
            option = "--" + name.replace("_", "-")
            parser.error(f"{option} is required (or set RIL_{name.upper()})")
    args.base_url = args.base_url.rstrip("/")
    return args


def new_session() -> requests.Session:
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    retry = Retry(total=3, backoff_factor=2, status_forcelist=(408, 429, 500, 502, 503, 504))
    session.mount("https://", HTTPAdapter(max_retries=retry))
    session.mount("http://", HTTPAdapter(max_retries=retry))
    return session


def extract_csrf(html: str) -> str | None:
    for pattern in CSRF_PATTERNS:
        if match := pattern.search(html):
            return match.group(1)
    return None


def load_cv(session: requests.Session, base_url: str, csrf: str) -> dict:
    response = session.get(
        f"{base_url}/candidati/curriculum/load-cv",
        params={"curriculum_id": 0, "is_company": 0},
        headers={
            "Accept": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-TOKEN": csrf,
        },
        timeout=TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    try:
        item = response.json()["item"]
        item["id"]
    except (ValueError, KeyError, TypeError) as exc:
        raise UpdateError("Unexpected response from load-cv (not logged in?)") from exc
    return item


def update_cv(args: argparse.Namespace) -> dict[str, str]:
    base_url = args.base_url
    cv_file: Path = args.cv_file

    if not cv_file.is_file():
        raise UpdateError(f"CV file '{cv_file}' does not exist")
    file_size = cv_file.stat().st_size
    if file_size > MAX_SIZE_BYTES:
        raise UpdateError(
            f"CV file is {file_size} bytes, the website accepts at most {MAX_SIZE_BYTES}"
        )

    session = new_session()

    # 1. Open the login page (session cookie + CSRF token)
    log.info("Opening login page")
    response = session.get(f"{base_url}/login", timeout=TIMEOUT_SECONDS)
    response.raise_for_status()
    csrf = extract_csrf(response.text)
    if not csrf:
        raise UpdateError("Unable to find the CSRF token in the login page")

    # 2. Log in
    log.info("Logging in")
    response = session.post(
        f"{base_url}/login",
        data={
            "_token": csrf,
            "email": args.email,
            "password": args.password,
            "login_path": "login",
        },
        headers={"Referer": f"{base_url}/login"},
        timeout=TIMEOUT_SECONDS,
    )
    if response.url.startswith(f"{base_url}/login") and 'name="password"' in response.text:
        raise UpdateError("Login failed: check the email/password secrets")

    # 3. Open the CV page to get the CSRF token bound to the authenticated session
    log.info("Opening CV page")
    response = session.get(f"{base_url}/candidati/curriculum", timeout=TIMEOUT_SECONDS)
    response.raise_for_status()
    csrf = extract_csrf(response.text)
    if not csrf:
        raise UpdateError("Unable to find the CSRF token in the CV page (not logged in?)")

    # 4. Retrieve the curriculum id
    log.info("Retrieving curriculum metadata")
    before = load_cv(session, base_url, csrf)
    curriculum_id = before["id"]
    previous_file = before.get("nome_file") or ""
    log.info("Curriculum id: %s (current file: '%s')", curriculum_id, previous_file or "<none>")

    # 5. Upload the new CV (same request the `uploadifive` widget sends)
    log.info("Uploading '%s' (%d bytes)", cv_file, file_size)
    with cv_file.open("rb") as fh:
        response = session.post(
            f"{base_url}/candidati/curriculum/documento",
            params={"curriculum_id": curriculum_id},
            data={"_token": csrf},
            files={"Filedata": (cv_file.name, fh)},
            headers={
                "Referer": f"{base_url}/candidati/curriculum",
                "X-Requested-With": "XMLHttpRequest",
                "X-CSRF-TOKEN": csrf,
            },
            timeout=TIMEOUT_SECONDS,
        )
    log.debug("Upload response (HTTP %d): %s", response.status_code, response.text[:500])
    if not response.ok:
        raise UpdateError(f"Upload failed with HTTP {response.status_code}")

    try:
        new_file = json.loads(response.text).get("src") or ""
    except (ValueError, AttributeError):
        match = SRC_PATTERN.search(response.text)
        new_file = match.group(1) if match else ""

    # 6. Verify
    after = load_cv(session, base_url, csrf)
    current_file = after.get("nome_file") or ""
    file_date = after.get("file_date") or ""
    document_id = after.get("documento_id") or ""

    if not current_file or current_file == previous_file:
        raise UpdateError(
            f"Upload did not replace the CV (server said: {response.text[:300]})"
        )
    if new_file and new_file != current_file:
        log.warning("Upload returned '%s' but profile points to '%s'", new_file, current_file)

    log.info("CV updated: %s (document %s, %s)", current_file, document_id, file_date)
    return {
        "curriculum-id": str(curriculum_id),
        "document-id": str(document_id),
        "file-path": str(current_file),
        "file-date": str(file_date),
    }


def main() -> int:
    logging.basicConfig(
        format="[%(asctime)s] %(levelname)s - %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
        level=logging.INFO,
    )
    log.setLevel(logging.DEBUG)
    args = parse_args()

    # Never print the password in the workflow logs
    if os.environ.get("GITHUB_ACTIONS"):
        print(f"::add-mask::{args.password}", flush=True)

    try:
        outputs = update_cv(args)
    except (UpdateError, requests.RequestException) as exc:
        log.error("%s", exc)
        print(f"::error title=reteinformaticalavoro::{exc}", flush=True)
        return 1

    if github_output := os.environ.get("GITHUB_OUTPUT"):
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.writelines(f"{key}={value}\n" for key, value in outputs.items())
    return 0


if __name__ == "__main__":
    sys.exit(main())
