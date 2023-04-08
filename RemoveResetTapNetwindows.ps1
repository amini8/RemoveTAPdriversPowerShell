function Remove-TapWindows {
    [CmdletBinding()]
    param (
        [switch]$Yes,
        [switch]$Wintun,
        [switch]$Help,
        [switch]$ResetNetConfig
    )

    function Show-Usage {
        Write-Host
        Write-Host "Usage: RemoveResetTapNetwindows.ps1 [-Wintun] [-Yes] [-Help] [-ResetNetConfig]"
        Write-Host
        Write-Host "Parameters:"
        Write-Host "    -Yes            Remove drivers instead of just showing what would get removed"
        Write-Host "    -Wintun         Remove Wintun drivers instead of tap-windows6 drivers"
        Write-Host "    -Help           Display this help message"
        Write-Host "    -ResetNetConfig Reset all network configuration settings to their defaults"
        Write-Host
        Write-host "Disclaimer: USE AT YOUR OWN RISK."
        exit 1
    }

    function Reset-WinNetConfig {
        [CmdletBinding()]
        param (
            [switch]$Confirm
        )

        if ($Confirm) {
            Write-Warning "This will reset all network configuration settings to their defaults."
            $confirmation = Read-Host "Are you sure you want to continue? (Y/N)"
            if ($confirmation.ToLower() -ne 'y') {
                Write-Verbose "Aborted resetting network configuration."
                return
            }
        }

        Write-Verbose "Resetting network configuration..."
        & netsh winsock reset
        & netsh int ip reset
        & ipconfig /release
        & ipconfig /renew
        Write-Verbose "Network configuration reset complete."
    }

    if ($Help) {
        Show-Usage
        return
    }

    if ($ResetNetConfig) {
        Reset-WinNetConfig -Verbose
    }

    if ($Wintun) {
        if (Test-Path 'C:\Program Files\Windscribe\WindscribeService.exe') {
            $provider = "windscribe"
        }
        elseif (Test-Path 'C:\Program Files\TunnelBear\TBear.Maintenance.exe') {
            $provider = "tunnelbear"
        }
        else {
            $provider = "WireGuard LLC"
        }
    } else {
        $provider = "TAP-Windows Provider V9"
    }

    $driverlist = & C:\Windows\System32\PnPutil.exe -e
    $driverlist = $driverlist -match '^(Published name|Driver package provider)'

    $tap_found = $false

    foreach ($line in $driverlist) {
        if ($line -match '^Published name:\s*(?<published_name>.+)$') {
            $published_name = $Matches['published_name']
        } elseif ($line -match '^Driver package provider:\s*(?<provider>.+)$') {
            if ($Matches['provider'] -eq $provider) {
                $tap_found = $true
                $openvpn_processes = Get-Process -Name "openvpn" -ErrorAction SilentlyContinue
                if ($openvpn_processes) {
                    Write-Verbose "Killing all openvpn processes..."
                    $openvpn_processes | Stop-Process -Force -ErrorAction SilentlyContinue
                }
                if ($Yes) { & PnPutil.exe -d $published_name }
                else      { Write-Verbose "Would remove ${published_name}" }
            }
        }
    }

    if (! $tap_found) {
        Write-Verbose "No tap-windows drivers found from the driver store."
    }
}

