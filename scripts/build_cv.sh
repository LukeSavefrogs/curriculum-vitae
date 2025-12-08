#!/bin/env bash
# **********************************************************************************
#                                                                                  *
# Description :                                                                    *
#                                                                                  *
# **********************************************************************************


# From: 
#      https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
#      https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o pipefail
set -o errtrace      # Same as `set -E`
set -o nounset       # Same as `set -u`
# set -o errexit     # Same as `set -e`, useful ONLY for short and simple scripts

main () {
    local output_dir="build"
    log_info "Starting the build process"

    if ! command -v uv &> /dev/null; then
        log_error "uv command could not be found. Please install [uv](https://docs.astral.sh/uv/) to proceed."
        return 1
    fi

    for file in cv-*.yaml; do
        lang="$(grep -Po '(?<=cv-)[-_a-z]{2}(?=\.yaml)' <<< "$file")"

        log_info "Rendering CV for language: ${lang} from file: ${file}"
        uv run rendercv render "$file" --output-folder-name "${output_dir}/${lang}/"
        log_info "Successfully rendered CV for language: ${lang}"
    done

    log_info "Build process completed successfully"
    return 0;
}

_log() {
    local level="${1?Missing mandatory log level}"
    local msg="${2?Missing mandatory log message}"
    echo "[$(date +'%Y-%m-%dT%H:%M:%S')] ${level^^} ${msg}"
}
log_info() { _log "DEBUG" "$@"; }
log_info() { _log "INFO" "$@"; }
log_warn() { _log "WARN" "$@"; }
log_error() { _log "ERROR" "$@"; }

main "$@"