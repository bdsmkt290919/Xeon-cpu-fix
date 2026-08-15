# Installation

## Linux

1. Ensure Bash is available.
2. Install recommended tooling:
   - `procps` for `top`
   - `util-linux` for `taskset`
   - `numactl` for NUMA-aware balancing
3. Clone the repository and make the scripts executable:

   ```bash
   chmod +x linux/*.sh
   ```

4. Review `config/config.yaml`.
5. Run the monitor or auto-balancer.

### Optional privileges

- Updating process affinity for system-owned processes may require `sudo`.
- IRQ affinity changes require elevated permissions to write under `/proc/irq`.

## Windows

1. Use Windows PowerShell 5.1+ or PowerShell 7+.
2. Open a PowerShell session with administrator rights if you plan to rebalance protected processes.
3. Allow script execution for the current session if needed:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   ```

4. Review `config\config.yaml`.
5. Run the monitor or auto-balancer from the repository root.

## Configuration

The same `config/config.yaml` file is used by both platforms. The default configuration:

```yaml
monitor_interval_seconds: 5
load_threshold_percent: 30
log_level: INFO
```
