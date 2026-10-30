#!/usr/bin/env bash
# **********************************************************************************
#                                                                                  *
# Description : Replace the CV document attached to a candidate profile on         *
#               https://reteinformaticalavoro.it                                   *
#                                                                                  *
#               The website exposes no public API, so this script reproduces       *
#               what the browser does, using only `curl` and `jq`:                 *
#                 1. GET  /login                         -> session + CSRF token   *
#                 2. POST /login                         -> authenticated session  *
#                 3. GET  /candidati/curriculum          -> fresh CSRF token       *
#                 4. GET  /candidati/curriculum/load-cv  -> curriculum id (JSON)   *
#                 5. POST /candidati/curriculum/documento?curriculum_id=<id>       *
#                         multipart field `Filedata`     -> upload (uploadifive)   *
#                 6. GET  /candidati/curriculum/load-cv  -> verify the new file    *
#                                                                                  *
# Environment : RIL_EMAIL, RIL_PASSWORD, RIL_CV_FILE (required)                    *
#               RIL_BASE_URL (optional, default https://reteinformaticalavoro.it)  *
#                                                                                  *
# **********************************************************************************
set -o pipefail
set -o errtrace
set -o nounset
set -o errexit

: "${RIL_EMAIL:?Missing RIL_EMAIL}"
: "${RIL_PASSWORD:?Missing RIL_PASSWORD}"
: "${RIL_CV_FILE:?Missing RIL_CV_FILE}"
declare -r BASE_URL="${RIL_BASE_URL:-https://reteinformaticalavoro.it}"
declare -r USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
declare -r MAX_SIZE_BYTES=$(( 10000 * 1024 ))  # uploadifive `fileSizeLimit: 1e4` (KB)

log()   { echo "[$(date +'%Y-%m-%dT%H:%M:%S')] ${1^^} - ${2}" >&2; }
fail()  { log "error" "$1"; echo "::error title=reteinformaticalavoro::$1"; exit 1; }

for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || fail "'$cmd' is required but not installed"
done

[[ -f "$RIL_CV_FILE" ]] || fail "CV file '$RIL_CV_FILE' does not exist"
file_size=$(stat -c %s "$RIL_CV_FILE")
(( file_size <= MAX_SIZE_BYTES )) || fail "CV file is ${file_size} bytes, the website accepts at most ${MAX_SIZE_BYTES}"

# Never print the password, even with `set -x`
[[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::add-mask::${RIL_PASSWORD}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
declare -r COOKIE_JAR="${workdir}/cookies.txt"

http() {
    curl --silent --show-error --location \
        --cookie "$COOKIE_JAR" --cookie-jar "$COOKIE_JAR" \
        --user-agent "$USER_AGENT" \
        --retry 3 --retry-delay 2 \
        "$@"
}

# Extract the Laravel CSRF token from either `<meta name="csrf-token">` or `<input name="_token">`
extract_csrf() {
    grep -oP '<meta name="csrf-token" content="\K[^"]+' "$1" | head -n1 \
        || grep -oP 'name="_token" value="\K[^"]+' "$1" | head -n1 \
        || true
}

load_cv() {
    local csrf="$1"
    http --fail \
        --header "Accept: application/json" \
        --header "X-Requested-With: XMLHttpRequest" \
        --header "X-CSRF-TOKEN: ${csrf}" \
        --get --data "curriculum_id=0" --data "is_company=0" \
        "${BASE_URL}/candidati/curriculum/load-cv"
}

# ---------------------------------------------------------------------------------
# 1. Open the login page (session cookie + CSRF token)
# ---------------------------------------------------------------------------------
log "info" "Opening login page"
http --fail --output "${workdir}/login.html" "${BASE_URL}/login"
csrf="$(extract_csrf "${workdir}/login.html")"
[[ -n "$csrf" ]] || fail "Unable to find the CSRF token in the login page"

# ---------------------------------------------------------------------------------
# 2. Log in
# ---------------------------------------------------------------------------------
log "info" "Logging in"
http --output "${workdir}/after-login.html" \
    --write-out '%{url_effective}' \
    --referer "${BASE_URL}/login" \
    --data-urlencode "_token=${csrf}" \
    --data-urlencode "email=${RIL_EMAIL}" \
    --data-urlencode "password=${RIL_PASSWORD}" \
    --data-urlencode "login_path=login" \
    "${BASE_URL}/login" > "${workdir}/after-login.url"

if grep -q 'name="password"' "${workdir}/after-login.html" \
    && [[ "$(cat "${workdir}/after-login.url")" == "${BASE_URL}/login"* ]]; then
    fail "Login failed: check the email/password secrets"
fi

# ---------------------------------------------------------------------------------
# 3. Open the CV page to get the CSRF token bound to the authenticated session
# ---------------------------------------------------------------------------------
log "info" "Opening CV page"
http --fail --output "${workdir}/curriculum.html" "${BASE_URL}/candidati/curriculum"
csrf="$(extract_csrf "${workdir}/curriculum.html")"
[[ -n "$csrf" ]] || fail "Unable to find the CSRF token in the CV page (not logged in?)"

# ---------------------------------------------------------------------------------
# 4. Retrieve the curriculum id
# ---------------------------------------------------------------------------------
log "info" "Retrieving curriculum metadata"
load_cv "$csrf" > "${workdir}/cv-before.json" || fail "Unable to load curriculum metadata"
jq -e '.item.id' "${workdir}/cv-before.json" &>/dev/null || fail "Unexpected response from load-cv (not logged in?)"
curriculum_id="$(jq -r '.item.id' "${workdir}/cv-before.json")"
previous_file="$(jq -r '.item.nome_file // ""' "${workdir}/cv-before.json")"
log "info" "Curriculum id: ${curriculum_id} (current file: '${previous_file:-<none>}')"

# ---------------------------------------------------------------------------------
# 5. Upload the new CV (same request the `uploadifive` widget sends)
# ---------------------------------------------------------------------------------
log "info" "Uploading '${RIL_CV_FILE}' (${file_size} bytes)"
http_code="$(
    http --output "${workdir}/upload.out" --write-out '%{http_code}' \
        --referer "${BASE_URL}/candidati/curriculum" \
        --header "X-Requested-With: XMLHttpRequest" \
        --header "X-CSRF-TOKEN: ${csrf}" \
        --form "_token=${csrf}" \
        --form "Filedata=@${RIL_CV_FILE};filename=$(basename "$RIL_CV_FILE")" \
        "${BASE_URL}/candidati/curriculum/documento?curriculum_id=${curriculum_id}"
)"
log "debug" "Upload response (HTTP ${http_code}): $(head -c 500 "${workdir}/upload.out")"
[[ "$http_code" == 2* ]] || fail "Upload failed with HTTP ${http_code}"

# The page `eval`s the response, so it may be a JS object literal rather than strict JSON
new_file="$(jq -r '.src // empty' "${workdir}/upload.out" 2>/dev/null \
    || grep -oP '["'"'"']?src["'"'"']?\s*:\s*["'"'"']\K[^"'"'"']+' "${workdir}/upload.out" \
    || true)"

# ---------------------------------------------------------------------------------
# 6. Verify
# ---------------------------------------------------------------------------------
load_cv "$csrf" > "${workdir}/cv-after.json" || fail "Unable to reload curriculum metadata"
current_file="$(jq -r '.item.nome_file // ""' "${workdir}/cv-after.json")"
file_date="$(jq -r '.item.file_date // ""' "${workdir}/cv-after.json")"
document_id="$(jq -r '.item.documento_id // ""' "${workdir}/cv-after.json")"

if [[ -z "$current_file" || "$current_file" == "$previous_file" ]]; then
    fail "Upload did not replace the CV (server said: $(head -c 300 "${workdir}/upload.out"))"
fi
[[ -n "$new_file" && "$new_file" != "$current_file" ]] \
    && log "warn" "Upload returned '${new_file}' but profile points to '${current_file}'"

log "info" "CV updated: ${current_file} (document ${document_id}, ${file_date})"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "curriculum-id=${curriculum_id}"
        echo "document-id=${document_id}"
        echo "file-path=${current_file}"
        echo "file-date=${file_date}"
    } >> "$GITHUB_OUTPUT"
fi
