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

do {
    $cpuInfo = Get-CimInstance -ClassName Win32_Processor
    $perCore = Get-PerCoreCpuLoad
    $topProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, Id, CPU

    Write-Host ("Timestamp: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    foreach ($processor in $cpuInfo) {
        Write-Host ("Processor: {0} | Cores: {1} | LogicalProcessors: {2} | CurrentClockMHz: {3}" -f $processor.Name.Trim(), $processor.NumberOfCores, $processor.NumberOfLogicalProcessors, $processor.CurrentClockSpeed)
    }

    $perCore | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "Top CPU consumers:"
    $topProcesses | Format-Table -AutoSize | Out-String | Write-Host

    Write-Log -Level "INFO" -Message "Windows monitor sample collected"

    if (-not $Once) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} until ($Once)
