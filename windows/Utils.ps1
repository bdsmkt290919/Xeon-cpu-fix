Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:UtilsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RepositoryRoot = Split-Path -Parent $script:UtilsDirectory
$script:ConfigFile = Join-Path $script:RepositoryRoot "config/config.yaml"
$script:ConfigCache = $null
$script:ResolvedLogFilePath = $null

function Get-ConfigCache {
    if ($null -ne $script:ConfigCache) {
        return $script:ConfigCache
    }

    $cache = @{}
    if (Test-Path -LiteralPath $script:ConfigFile) {
        foreach ($line in Get-Content -LiteralPath $script:ConfigFile) {
            if ($line -match '^\s*#' -or $line -notmatch ':') {
                continue
            }

            $parts = $line -split ':', 2
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            if ($value.StartsWith('"') -and $value -match '^"(.*)"(?:\s+#.*)?$') {
                $value = $Matches[1]
            }
            elseif ($value.StartsWith("'") -and $value -match "^'(.*)'(?:\s+#.*)?$") {
                $value = $Matches[1]
            }
            else {
                $value = ($value -replace '\s+#.*$', '').Trim()
            }
            if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $cache[$key] = $value
        }
    }

    $script:ConfigCache = $cache
    return $script:ConfigCache
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter()]
        [string]$DefaultValue = ""
    )

    $cache = Get-ConfigCache
    if ($cache.ContainsKey($Key)) {
        return $cache[$Key]
    }

    return $DefaultValue
}

function Get-LogFilePath {
    if ($null -ne $script:ResolvedLogFilePath) {
        return $script:ResolvedLogFilePath
    }

    $configured = Get-ConfigValue -Key "log_file" -DefaultValue "logs/xeon-cpu-fix.log"
    if ([System.IO.Path]::IsPathRooted($configured)) {
        $script:ResolvedLogFilePath = $configured
        return $script:ResolvedLogFilePath
    }

    $script:ResolvedLogFilePath = Join-Path $script:RepositoryRoot $configured
    return $script:ResolvedLogFilePath
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
