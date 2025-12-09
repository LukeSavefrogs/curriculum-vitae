#!/bin/env bash
# **********************************************************************************
#                                                                                  *
# Description : Generate the CVs for each `cv-*.yaml` file.                        *
#                                                                                  *
# **********************************************************************************


# From: 
#      https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
#      https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o pipefail
set -o errtrace      # Same as `set -E`
set -o nounset       # Same as `set -u`
set -o errexit       # Same as `set -e`

declare -r PROJECT_ROOT="$(realpath -e "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/..")"

main () {
    local output_dir="build"

    if ! command -v uv &> /dev/null; then
        log_error "uv command could not be found. Please install [uv](https://docs.astral.sh/uv/) to proceed."
        return 1
    fi

    log_info "Starting the build process (project.root='${PROJECT_ROOT}')"

    for file in cv-*.yaml; do
        lang="$(grep -Po '(?<=cv-)([-_a-z]{2})(?=\.yaml)' <<< "$file")"

        log_debug "Rendering CV for language '${lang}' from file '${file}'"
        uv run rendercv render "$file" \
            --output-folder-name "${output_dir}/${lang}/" \
            --rendercv-settings "${PROJECT_ROOT}/config/rendercv.config.yaml"
        log_info "Successfully rendered CV for language '${lang}'"
    done

    log_info "Build process completed successfully"
    return 0;
}

# Logging functions
_log() {
    local level="${1?Missing mandatory log level}"
    local msg="${2?Missing mandatory log message}"
    echo "[$(date +'%Y-%m-%dT%H:%M:%S')] ${level^^} - ${msg}"
}
log_debug() { _log "DEBUG" "$@"; }
log_info() { _log "INFO" "$@"; }
log_warn() { _log "WARN" "$@"; }
log_error() { _log "ERROR" "$@"; }

main "$@"