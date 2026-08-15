#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_command top

INTERVAL="$(linux_interval)"
TOP_LINES="$(config_value "linux_top_snapshot_lines" "15")"
RUN_ONCE=false
SAMPLE_DELAY="${INTERVAL}"

if [[ "${1:-}" == "--once" ]]; then
    RUN_ONCE=true
    SAMPLE_DELAY=1
fi

declare -A PREV_TOTALS
declare -A PREV_IDLES

capture_snapshot() {
    while read -r cpu_id total idle; do
        PREV_TOTALS["${cpu_id}"]="${total}"
        PREV_IDLES["${cpu_id}"]="${idle}"
    done < <(read_cpu_totals)
}

print_cycle() {
    local output=""
    while read -r cpu_id total idle; do
        local previous_total previous_idle usage
        previous_total="${PREV_TOTALS[${cpu_id}]:-0}"
        previous_idle="${PREV_IDLES[${cpu_id}]:-0}"
        usage="$(cpu_usage_percent "${previous_total}" "${previous_idle}" "${total}" "${idle}")"
        output+="cpu${cpu_id}: ${usage}%"$'\n'
        PREV_TOTALS["${cpu_id}"]="${total}"
        PREV_IDLES["${cpu_id}"]="${idle}"
    done < <(read_cpu_totals)

    printf 'Timestamp: %s\n%s' "$(date '+%Y-%m-%d %H:%M:%S')" "${output}"
    log_message "INFO" "Linux monitor sample collected"
    top -b -n 1 | head -n "${TOP_LINES}"
}

capture_snapshot

while true; do
    sleep "${SAMPLE_DELAY}"
    print_cycle
    if [[ "${RUN_ONCE}" == true ]]; then
        break
    fi
done
