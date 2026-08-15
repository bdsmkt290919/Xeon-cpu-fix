#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_command taskset

INTERVAL="$(linux_interval)"
THRESHOLD="$(linux_threshold)"
RUN_ONCE=false
SAMPLE_DELAY="${INTERVAL}"

if [[ "${1:-}" == "--once" ]]; then
    RUN_ONCE=true
    SAMPLE_DELAY=1
fi

declare -A PREV_TOTALS
declare -A PREV_IDLES
declare -A USAGE_BY_CPU

capture_snapshot() {
    while read -r cpu_id total idle; do
        PREV_TOTALS["${cpu_id}"]="${total}"
        PREV_IDLES["${cpu_id}"]="${idle}"
    done < <(read_cpu_totals)
}

collect_usage() {
    sleep "${SAMPLE_DELAY}"
    while read -r cpu_id total idle; do
        local previous_total previous_idle usage
        previous_total="${PREV_TOTALS[${cpu_id}]:-0}"
        previous_idle="${PREV_IDLES[${cpu_id}]:-0}"
        usage="$(cpu_usage_percent "${previous_total}" "${previous_idle}" "${total}" "${idle}")"
        USAGE_BY_CPU["${cpu_id}"]="${usage}"
        PREV_TOTALS["${cpu_id}"]="${total}"
        PREV_IDLES["${cpu_id}"]="${idle}"
    done < <(read_cpu_totals)
}

is_candidate_process() {
    local process_name="$1"
    local names=()
    mapfile -t names < <(config_list "linux_candidate_processes")
    if [[ ${#names[@]} -eq 0 ]]; then
        return 0
    fi

    local candidate
    for candidate in "${names[@]}"; do
        if [[ "${candidate}" == "${process_name}" ]]; then
            return 0
        fi
    done

    return 1
}

find_hot_and_cool_cpus() {
    local hottest_cpu=-1
    local coolest_cpu=-1
    local hottest_load=-1
    local coolest_load=101
    local cpu_id usage

    for cpu_id in "${!USAGE_BY_CPU[@]}"; do
        usage="${USAGE_BY_CPU[${cpu_id}]}"
        if (( usage > hottest_load )); then
            hottest_cpu="${cpu_id}"
            hottest_load="${usage}"
        fi
        if (( usage < coolest_load )); then
            coolest_cpu="${cpu_id}"
            coolest_load="${usage}"
        fi
    done

    printf '%s %s %s %s\n' "${hottest_cpu}" "${hottest_load}" "${coolest_cpu}" "${coolest_load}"
}

rebalance_irqs() {
    local cool_cpu="$1"
    local enabled
    enabled="$(config_value "linux_irq_balance" "false")"
    if [[ "${enabled,,}" != "true" ]]; then
        return 0
    fi

    local changed=false
    local irq_file
    for irq_file in /proc/irq/*/smp_affinity_list; do
        [[ -w "${irq_file}" ]] || continue
        printf '%s\n' "${cool_cpu}" > "${irq_file}" || true
        changed=true
    done

    if [[ "${changed}" == true ]]; then
        log_message "INFO" "Updated writable IRQ affinity lists to CPU ${cool_cpu}"
    else
        log_message "WARN" "IRQ balancing requested but no writable IRQ affinity files were found"
    fi
}

log_numa_hint() {
    local hot_cpu="$1"
    local cool_cpu="$2"
    local enabled
    enabled="$(config_value "linux_numactl" "false")"
    if [[ "${enabled,,}" != "true" ]]; then
        return 0
    fi

    if ! command -v numactl >/dev/null 2>&1; then
        log_message "WARN" "NUMA guidance requested but numactl is not installed"
        return 0
    fi

    local cpu_nodes
    cpu_nodes="$(lscpu -p=cpu,node 2>/dev/null | grep -v '^#' || true)"
    if [[ -z "${cpu_nodes}" ]]; then
        log_message "WARN" "NUMA guidance requested but CPU/node mapping is unavailable"
        return 0
    fi

    local hot_node cool_node
    hot_node="$(awk -F',' -v cpu="${hot_cpu}" '$1 == cpu { print $2; exit }' <<< "${cpu_nodes}")"
    cool_node="$(awk -F',' -v cpu="${cool_cpu}" '$1 == cpu { print $2; exit }' <<< "${cpu_nodes}")"
    log_message "INFO" "NUMA hint: consider launching hot workloads with numactl --cpunodebind=${cool_node:-0} --membind=${cool_node:-0} to move pressure from node ${hot_node:-0}"
}

rebalance_processes() {
    local hot_cpu="$1"
    local cool_cpu="$2"
    local moved_any=false

    affinity_contains_cpu() {
        local affinity="$1"
        local cpu="$2"
        local segment start end
        IFS=',' read -ra segments <<< "${affinity}"
        for segment in "${segments[@]}"; do
            if [[ "${segment}" == *-* ]]; then
                start="${segment%-*}"
                end="${segment#*-}"
                if (( cpu >= start && cpu <= end )); then
                    return 0
                fi
            elif [[ "${segment}" == "${cpu}" ]]; then
                return 0
            fi
        done
        return 1
    }

    while read -r pid cpu_usage process_name; do
        [[ -n "${pid}" ]] || continue
        if ! is_candidate_process "${process_name}"; then
            continue
        fi
        local current_affinity
        current_affinity="$(taskset -pc "${pid}" 2>/dev/null | awk -F': ' 'NR == 1 { print $2 }')"
        if [[ -z "${current_affinity}" ]] || ! affinity_contains_cpu "${current_affinity}" "${hot_cpu}"; then
            continue
        fi
        if taskset -pc "${cool_cpu}" "${pid}" >/dev/null 2>&1; then
            log_message "INFO" "Moved PID ${pid} (${process_name}) to CPU ${cool_cpu} from hot CPU ${hot_cpu}"
            moved_any=true
        else
            log_message "WARN" "Unable to move PID ${pid} (${process_name}); higher privileges may be required"
        fi
    done < <(ps -eo pid,pcpu,comm --no-headers | awk '$2 > 0.5 { print $1, $2, $3 }')

    if [[ "${moved_any}" == false ]]; then
        log_message "INFO" "No eligible Linux processes found on CPU ${hot_cpu} for rebalancing"
    fi
}

capture_snapshot

while true; do
    collect_usage
    read -r hottest_cpu hottest_load coolest_cpu coolest_load < <(find_hot_and_cool_cpus)

    if (( hottest_load < THRESHOLD )); then
        log_message "INFO" "No Linux rebalance required; hottest CPU ${hottest_cpu} at ${hottest_load}%"
    elif [[ "${hottest_cpu}" == "${coolest_cpu}" ]]; then
        log_message "INFO" "No Linux rebalance required; only one logical CPU detected"
    else
        log_message "INFO" "Rebalancing Linux workload: CPU ${hottest_cpu} at ${hottest_load}% -> CPU ${coolest_cpu} at ${coolest_load}%"
        rebalance_processes "${hottest_cpu}" "${coolest_cpu}"
        rebalance_irqs "${coolest_cpu}"
        log_numa_hint "${hottest_cpu}" "${coolest_cpu}"
    fi

    if [[ "${RUN_ONCE}" == true ]]; then
        break
    fi
    SAMPLE_DELAY="${INTERVAL}"
done
