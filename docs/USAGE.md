# Usage

## Linux monitor

Run continuously:

```bash
/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/linux/monitor.sh
```

Run a single sample:

```bash
/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/linux/monitor.sh --once
```

The monitor reads `/proc/stat`, calculates per-core load between samples, and appends log entries to `logs/xeon-cpu-fix.log`. Each cycle also prints a `top` snapshot.

## Linux auto-balance

```bash
/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/linux/auto-balance.sh --once
```

Behavior:

- Detects hot cores above `load_threshold_percent`
- Identifies candidate processes on the busiest core
- Reassigns process affinity with `taskset`
- Optionally updates IRQ affinity when `linux_irq_balance: true`
- Optionally logs NUMA recommendations when `linux_numactl: true`

Use `linux_candidate_processes` as a comma-separated allow-list if you only want to rebalance specific processes.

## Windows monitor

```powershell
.\windows\Monitor.ps1
.\windows\Monitor.ps1 -Once
```

Behavior:

- Reads CPU information from `Win32_Processor`
- Collects per-core usage from `\Processor(*)\% Processor Time`
- Prints the busiest cores and top CPU-consuming processes
- Writes log entries to the shared log file

## Windows auto-balance

```powershell
.\windows\AutoBalance.ps1
.\windows\AutoBalance.ps1 -Once
```

Behavior:

- Detects overloaded logical processors
- Selects high-CPU processes, or the configured process allow-list
- Updates process affinity masks to move load toward cooler cores

## Logging

All scripts log to the path configured by `log_file`. By default:

```text
logs/xeon-cpu-fix.log
```
