param(
    [string]$Title = "Claude Code",
    [string]$Message = "",
    [string]$EventType = "general",
    [int]$LongRunThresholdSec = 180
)

$ErrorActionPreference = 'Stop'

function Resolve-Payload {
    try {
        $inputRaw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($inputRaw)) {
            return $null
        }
        return ($inputRaw | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Get-ElapsedSecFromPayload {
    param([object]$Payload)

    if ($null -eq $Payload) {
        return $null
    }

    $candidates = @(
        $Payload.elapsed_ms,
        $Payload.duration_ms,
        $Payload.durationMs,
        $Payload.run_time_ms,
        $Payload.runtime_ms,
        $Payload.elapsedMs,
        $Payload.event.elapsed_ms,
        $Payload.event.duration_ms,
        $Payload.data.elapsed_ms,
        $Payload.data.duration_ms
    )

    foreach ($value in $candidates) {
        if ($null -ne $value -and "$value" -match '^\d+(\.\d+)?$') {
            return [math]::Round(([double]$value) / 1000.0)
        }
    }

    return $null
}

function Format-Duration {
    param([int]$Seconds)

    if ($Seconds -lt 60) {
        return "${Seconds}s"
    }

    $minutes = [math]::Floor($Seconds / 60)
    $remain = $Seconds % 60
    if ($remain -eq 0) {
        return "${minutes}m"
    }

    return "${minutes}m ${remain}s"
}

function Resolve-Message {
    param(
        [string]$InputEventType,
        [string]$InputMessage,
        [object]$Payload,
        [int]$ThresholdSec
    )

    $effectiveEventType = $InputEventType
    if ($Payload -and -not [string]::IsNullOrWhiteSpace([string]$Payload.matcher)) {
        $effectiveEventType = [string]$Payload.matcher
    }

    if (-not [string]::IsNullOrWhiteSpace($InputMessage)) {
        return $InputMessage
    }

    $elapsedSec = Get-ElapsedSecFromPayload -Payload $Payload

    switch ($effectiveEventType) {
        'stop' {
            if ($null -ne $elapsedSec -and $elapsedSec -ge $ThresholdSec) {
                return "Task completed (long run: $(Format-Duration -Seconds $elapsedSec))"
            }
            return "Task completed"
        }
        'permission_prompt' {
            return "Permission required before command execution"
        }
        'idle_prompt' {
            return "Waiting for your next input"
        }
        'error' {
            return "Task error occurred. Check terminal/logs"
        }
        default {
            return "New Claude event in current session"
        }
    }
}

function Send-ToastNotification {
    param(
        [string]$ToastTitle,
        [string]$ToastMessage
    )

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        $template = '<toast><visual><binding template="ToastText02"><text id="1">' + $ToastTitle + '</text><text id="2">' + $ToastMessage + '</text></binding></visual><audio src="ms-winsoundevent:Notification.Default"/></toast>'

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ClaudeCode').Show($toast)
        return $true
    }
    catch {
        return $false
    }
}

function Send-BalloonNotification {
    param(
        [string]$BalloonTitle,
        [string]$BalloonMessage
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Information
        $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $notification.BalloonTipTitle = $BalloonTitle
        $notification.BalloonTipText = $BalloonMessage
        $notification.Visible = $true
        $notification.ShowBalloonTip(5000)
        Start-Sleep -Milliseconds 5000
        $notification.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

$payload = Resolve-Payload
$finalMessage = Resolve-Message -InputEventType $EventType -InputMessage $Message -Payload $payload -ThresholdSec $LongRunThresholdSec

$success = Send-ToastNotification -ToastTitle $Title -ToastMessage $finalMessage
if (-not $success) {
    Write-Host "Toast notification failed, trying balloon notification..."
    $success = Send-BalloonNotification -BalloonTitle $Title -BalloonMessage $finalMessage
}

if ($success) {
    Write-Host "Notification sent successfully: $finalMessage"
    exit 0
}

Write-Host "All notification methods failed"
exit 1
