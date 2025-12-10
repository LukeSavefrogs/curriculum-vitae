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
declare -r TMUX_SESSION_NAME="build_cv_$$"
declare WATCH_MODE=false

declare -r COLS_PER_ROW_RATIO=2  # Number of columns per row to decide tmux layout

main () {
    local output_dir="build"
    local is_tmux_available=false tmux_disabled=false
    local -a command_prefix=()

    # From this excellent StackOverflow answer: https://stackoverflow.com/a/14203146/8965861
    OPTIND=1;
    POSITIONAL=();
    while (( $# > 0 )); do
        case $1 in
            -w | --watch)
                WATCH_MODE=true;
                POSITIONAL+=("$1");
                shift;
            ;;
            --no-tmux)
                tmux_disabled=true;
                is_tmux_available=false;
                shift;
            ;;
            -\? | -h |--help)
                printf "Usage: %s [options] [-- <uv rendercv options>]\n" "$(basename "$0")"
                printf "\n"
                printf "Description:\n"
                printf "  This script generates CVs for each 'cv-*.yaml' file found in the project root directory.\n"
                printf "  It uses the 'uv' command-line tool to render the CVs based on the specified design and settings.\n"
                printf "\n"
                printf "Options:\n"
                printf "  -w, --watch          Enable watch mode to monitor changes and rebuild automatically\n"
                printf "  -h, --help           Show this help message and exit\n"
                return 0;
            ;;
            --)
                shift;
                while (( $# > 0 )); do POSITIONAL+=("$1"); shift; done
                break;
            ;;
            -*)
                printf "ERROR: Unknown option '%s'" "$1" >&2;
                return 1;
            ;;
            *)
                POSITIONAL+=("$1");
                shift;
            ;;
        esac;
    done;
    [[ ${#POSITIONAL[@]} -gt 0 ]] && set -- "${POSITIONAL[@]}";

    if ! command -v uv &> /dev/null; then
        log_error "uv command could not be found. Please install [uv](https://docs.astral.sh/uv/) to proceed."
        return 1
    fi

    if command -v tmux &> /dev/null && [[ -t 1 ]] && [[ $tmux_disabled == false ]]; then
        is_tmux_available=true
    elif [[ $WATCH_MODE == true ]]; then
        log_warn "tmux can not be used. Watch mode will be run one file at a time."
    fi

    if $is_tmux_available; then
        tmux_create_session "$TMUX_SESSION_NAME"
        command_prefix=(tmux_send_command "$TMUX_SESSION_NAME")
    fi

    log_info "Starting the build process (project.root='${PROJECT_ROOT}')"

    for file in cv-*.yaml; do
        lang="$(grep -Po '(?<=cv-)([-_a-z]{2})(?=\.yaml)' <<< "$file")"

        log_debug "Rendering CV for language '${lang}' from file '${file}'"
        "${command_prefix[@]}" uv run rendercv render "$file" \
            --output-folder-name "${output_dir}/${lang}/" \
            --design "${PROJECT_ROOT}/config/design.yaml" \
            --rendercv-settings "${PROJECT_ROOT}/config/rendercv.settings.yaml" \
            "$@"
        log_info "Successfully rendered CV for language '${lang}'"
    done

    if $is_tmux_available; then
        tmux_attach_session "$TMUX_SESSION_NAME"
    fi

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

tmux_create_session() {
    tmux new-session -d -s "${1?Missing mandatory tmux session}"
}

tmux_send_command() {
    local session="${1?Missing mandatory tmux session}"
    shift
    local command="${@?Missing mandatory tmux command}"

    tmux split-window -h -t "$session"
    tmux send-keys -t "$session" "$command" C-m
}

tmux_attach_session() {
    local session="${1?Missing mandatory tmux session}"
    shift

    pane_count=$(tmux display-message -p -t "$session" "#{window_panes}")
    if [[ "$pane_count" -gt 1 ]]; then
        tmux kill-pane -t "${session}:0.0"
    fi

    # If the terminal is wider than tall, use horizontal layout; otherwise, vertical
    local cols rows
    read rows cols < <(stty size)

    if ((cols > (rows * COLS_PER_ROW_RATIO))); then
        tmux select-layout even-horizontal
    else
        tmux select-layout even-vertical
    fi

    # Enable synchronized panes to send input to all panes simultaneously
    tmux set-window-option -t "$session":0 synchronize-panes on

    tmux attach-session -t "$session"
}

main "$@"