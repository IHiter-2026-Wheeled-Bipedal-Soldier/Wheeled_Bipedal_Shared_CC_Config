param(
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceFolder = ""
)

$ErrorActionPreference = 'Stop'

# 如果未传入参数，使用当前目录
if ([string]::IsNullOrWhiteSpace($WorkspaceFolder)) {
    $WorkspaceFolder = Get-Location
}

Write-Host "[DEBUG] WorkspaceFolder: $WorkspaceFolder"

# 读取缓存的 UV4 和项目路径
$cacheFile = Join-Path $WorkspaceFolder '.vscode\keil-path-cache.json'

if (Test-Path $cacheFile) {
    $cache = Get-Content $cacheFile | ConvertFrom-Json
    $uv4Path = $cache.uv4Path
    $projectPath = $cache.projectPath
} else {
    # 默认 UV4 路径
    $uv4Path = 'D:\Programfile\MDK\Core\UV4\UV4.exe'
    $projectPath = ''
}

# 验证 UV4.exe
if (-not (Test-Path $uv4Path)) {
    Write-Host "[ERROR] UV4.exe not found at: $uv4Path"
    exit 1
}

# 验证项目路径，如无效则重新扫描
if ([string]::IsNullOrWhiteSpace($projectPath) -or -not (Test-Path $projectPath)) {
    Write-Host "[INFO] Cached project path invalid, scanning..."
    $found = Get-ChildItem -Path $WorkspaceFolder -Recurse -Filter '*.uvprojx' | Select-Object -First 1
    if ($found) {
        $projectPath = $found.FullName
        Write-Host "[INFO] Found project: $projectPath"
    }
}

if (-not (Test-Path $projectPath)) {
    Write-Host "[ERROR] No .uvprojx found in workspace"
    exit 1
}

# 设置日志路径
$logPath = Join-Path $WorkspaceFolder 'Project\.vscode\uv4.log'
$logDir = Split-Path -Parent $logPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# 执行构建
Write-Host "[BUILD] UV4: $uv4Path"
Write-Host "[BUILD] Project: $projectPath"
Write-Host "[BUILD] Log: $logPath"

$uv4Args = @('-b', $projectPath, '-j0', '-t', 'Target', '-o', $logPath)
$proc = Start-Process -FilePath $uv4Path -ArgumentList $uv4Args -Wait -PassThru -NoNewWindow

# 读取结果
if (Test-Path $logPath) {
    $logContent = Get-Content $logPath -Raw
    if ($logContent -match '0 Error\(s\)') {
        Write-Host "[SUCCESS] Build clean. 0 Error(s)."
        return
    } else {
        Write-Host "[FAILED] Build errors:"
        $errLines = ($logContent -split "`n") | Where-Object { $_ -match 'error:|Error\(' } | Select-Object -First 10
        $errLines | ForEach-Object { Write-Host $_ }
        exit 1
    }
} else {
    Write-Host "[ERROR] Log file not found"
    exit 1
}
