# xeon-cpu-fix

Hybrid tooling for monitoring and auto-balancing CPU load on Intel Xeon systems across Linux and Windows.

## Features

- Real-time per-core CPU monitoring
- Automatic workload balancing based on configurable load thresholds
- Shared `config/config.yaml` configuration for both platforms
- File and console logging for monitoring and troubleshooting

## Project Layout

```text
xeon-cpu-fix/
├── config/config.yaml
├── docs/INSTALL.md
├── docs/USAGE.md
├── linux/
│   ├── auto-balance.sh
│   ├── monitor.sh
│   └── utils.sh
├── logs/.gitkeep
└── windows/
    ├── AutoBalance.ps1
    ├── Monitor.ps1
    └── Utils.ps1
```

## Quick Start

### Linux

```bash
chmod +x /home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/linux/*.sh
/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/linux/monitor.sh --once
/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/linux/auto-balance.sh --once
```

### Windows

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\Monitor.ps1 -Once
.\windows\AutoBalance.ps1 -Once
```

## Configuration

Common settings live in `config/config.yaml`:

- `monitor_interval_seconds: 5`
- `load_threshold_percent: 30`
- `log_level: INFO`

Additional Linux and Windows options are included for process targeting and balancing behavior.

## Platform Notes

- Linux balancing uses `taskset` for affinity updates, optional IRQ balancing, and optional NUMA-aware guidance when `numactl` is available.
- Windows balancing uses WMI/CIM and performance counters for monitoring and adjusts process affinity masks for selected workloads.
- Some balancing operations require elevated privileges.

## Documentation

- Installation: `/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/docs/INSTALL.md`
- Usage: `/home/runner/work/Xeon-cpu-fix/Xeon-cpu-fix/docs/USAGE.md`
