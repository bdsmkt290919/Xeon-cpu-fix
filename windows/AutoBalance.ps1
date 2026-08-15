param(
    [int]$IntervalSeconds = 0,
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Utils.ps1")

if ($IntervalSeconds -le 0) {
    $IntervalSeconds = [int](Get-ConfigValue -Key "monitor_interval_seconds" -DefaultValue "5")
}

function Get-TargetProcesses {
    $candidateNames = Get-ConfigList -Key "windows_candidate_processes"
    $processes = Get-Process | Where-Object { $_.Id -ne $PID -and $_.ProcessName -notin @("Idle", "System") }

    if ($candidateNames.Count -gt 0) {
        return $processes | Where-Object { $_.ProcessName -in $candidateNames } | Sort-Object CPU -Descending
    }

    return $processes | Sort-Object CPU -Descending | Select-Object -First 5
}

function Set-ProcessAffinityToCore {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [int]$Core
    )

    try {
        $mask = [int64]1 -shl $Core
        $Process.ProcessorAffinity = [IntPtr]$mask
        Write-Log -Level "INFO" -Message ("Moved PID {0} ({1}) to logical core {2}" -f $Process.Id, $Process.ProcessName, $Core)
    }
    catch {
        Write-Log -Level "WARN" -Message ("Unable to adjust PID {0} ({1}): {2}" -f $Process.Id, $Process.ProcessName, $_.Exception.Message)
    }
}

$threshold = [int](Get-ConfigValue -Key "load_threshold_percent" -DefaultValue "30")

do {
    $perCore = Get-PerCoreCpuLoad
    if (-not $perCore) {
        Write-Log -Level "WARN" -Message "No per-core performance counter data was returned"
        if (-not $Once) {
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }
        break
    }

    $hotCore = $perCore | Sort-Object Load -Descending | Select-Object -First 1
    $coolCores = $perCore | Sort-Object Load, Core

    if ($hotCore.Load -lt $threshold) {
        Write-Log -Level "INFO" -Message ("No Windows rebalance required; hottest core {0} at {1}%%" -f $hotCore.Core, $hotCore.Load)
    }
    else {
        $targets = Get-TargetProcesses
        $coolIndex = 0
        foreach ($process in $targets) {
            $targetCore = $coolCores[$coolIndex % $coolCores.Count].Core
            Set-ProcessAffinityToCore -Process $process -Core $targetCore
            $coolIndex++
        }
    }

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} until ($Once)
