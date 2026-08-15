Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:UtilsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepositoryRoot = Split-Path -Parent $script:UtilsDirectory
$script:ConfigFile = Join-Path $script:RepositoryRoot "config/config.yaml"

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter()]
        [string]$DefaultValue = ""
    )

    if (-not (Test-Path -LiteralPath $script:ConfigFile)) {
        return $DefaultValue
    }

    foreach ($line in Get-Content -LiteralPath $script:ConfigFile) {
        if ($line -match '^\s*#' -or $line -notmatch ':') {
            continue
        }

        $parts = $line -split ':', 2
        if ($parts[0].Trim() -eq $Key) {
            return $parts[1].Trim().Trim('"')
        }
    }

    return $DefaultValue
}

function Get-ConfigList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $raw = Get-ConfigValue -Key $Key -DefaultValue ""
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    return $raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Get-LogFilePath {
    $configured = Get-ConfigValue -Key "log_file" -DefaultValue "logs/xeon-cpu-fix.log"
    if ([System.IO.Path]::IsPathRooted($configured)) {
        return $configured
    }

    return Join-Path $script:RepositoryRoot $configured
}

function Get-LogLevelRank {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level
    )

    switch ($Level.ToUpperInvariant()) {
        "DEBUG" { return 10 }
        "INFO"  { return 20 }
        "WARN"  { return 30 }
        "ERROR" { return 40 }
        default { return 20 }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $configuredLevel = Get-ConfigValue -Key "log_level" -DefaultValue "INFO"
    if ((Get-LogLevelRank -Level $Level) -lt (Get-LogLevelRank -Level $configuredLevel)) {
        return
    }

    $logFile = Get-LogFilePath
    $logDirectory = Split-Path -Parent $logFile
    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpperInvariant(), $Message
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line
}

function Get-PerCoreCpuLoad {
    $samples = Get-Counter '\Processor(*)\% Processor Time'
    $samples.CounterSamples |
        Where-Object { $_.InstanceName -ne "_Total" -and $_.InstanceName -match '^\d+$' } |
        Sort-Object { [int]$_.InstanceName } |
        ForEach-Object {
            [pscustomobject]@{
                Core = [int]$_.InstanceName
                Load = [math]::Round($_.CookedValue, 0)
            }
        }
}
