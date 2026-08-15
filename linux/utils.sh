#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${UTILS_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/config/config.yaml"

level_rank() {
    case "${1^^}" in
        DEBUG) echo 10 ;;
        INFO) echo 20 ;;
        WARN) echo 30 ;;
        ERROR) echo 40 ;;
        *) echo 20 ;;
    esac
}

config_value() {
    local key="$1"
    local default_value="${2:-}"
    local value
    value="$(awk -F':' -v wanted="${key}" '
        $0 ~ /^[[:space:]]*#/ { next }
        {
            current_key = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_key)
        }
        current_key == wanted {
            value = $0
            sub(/^[^:]+:[[:space:]]*/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            sub(/\r$/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}" 2>/dev/null || true)"

    if [[ -n "${value}" ]]; then
        printf '%s\n' "${value}"
    else
        printf '%s\n' "${default_value}"
    fi
}

config_list() {
    local key="$1"
    local raw
    raw="$(config_value "${key}" "")"
    raw="${raw//\"/}"
    raw="${raw// /}"
    if [[ -n "${raw}" ]]; then
        tr ',' '\n' <<< "${raw}" | sed '/^$/d'
    fi
}

log_file_path() {
    local configured
    configured="$(config_value "log_file" "logs/xeon-cpu-fix.log")"
    if [[ "${configured}" = /* ]]; then
        printf '%s\n' "${configured}"
    else
        printf '%s\n' "${REPO_ROOT}/${configured}"
    fi
}

ensure_log_dir() {
    mkdir -p "$(dirname "$(log_file_path)")"
}

log_message() {
    local level="${1^^}"
    local message="$2"
    local configured_level
    configured_level="$(config_value "log_level" "INFO")"

    if (( $(level_rank "${level}") < $(level_rank "${configured_level}") )); then
        return 0
    fi

    ensure_log_dir
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') [${level}] ${message}"
    printf '%s\n' "${line}" | tee -a "$(log_file_path)"
}

require_command() {
    local command_name="$1"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        log_message "ERROR" "Missing required command: ${command_name}"
        return 1
    fi
}

read_cpu_totals() {
    awk '
        /^cpu[0-9]+ / {
            total = 0
            for (i = 2; i <= NF; i++) {
                total += $i
            }
            idle = $5 + $6
            sub(/^cpu/, "", $1)
            printf "%s %s %s\n", $1, total, idle
        }
    ' /proc/stat
}

cpu_usage_percent() {
    local previous_total="$1"
    local previous_idle="$2"
    local current_total="$3"
    local current_idle="$4"
    awk -v pt="${previous_total}" -v pi="${previous_idle}" -v ct="${current_total}" -v ci="${current_idle}" '
        BEGIN {
            total_delta = ct - pt
            idle_delta = ci - pi
            if (total_delta <= 0) {
                print "0"
                exit
            }
            usage = ((total_delta - idle_delta) / total_delta) * 100
            printf "%.0f\n", usage
        }
    '
}

linux_interval() {
    config_value "monitor_interval_seconds" "5"
}

linux_threshold() {
    config_value "load_threshold_percent" "30"
}
