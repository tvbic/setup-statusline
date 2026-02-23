# statusline.ps1 - Claude Code status line script for Windows
$ErrorActionPreference = 'SilentlyContinue'

# 讀取 JSON 輸入
$inputData = [Console]::In.ReadToEnd()
$data = $null
try {
    $data = $inputData | ConvertFrom-Json
} catch {
    Write-Host -NoNewline "Context: Error parsing JSON"
    exit 0
}

# ---------------------------------------------------------------------------
# 取得目錄資訊
# ---------------------------------------------------------------------------
$cwd = if ($data.workspace.current_dir) { $data.workspace.current_dir } elseif ($data.cwd) { $data.cwd } else { Get-Location }
$currentDir = Split-Path -Leaf $cwd

# ---------------------------------------------------------------------------
# Context Window 剩餘容量
# ---------------------------------------------------------------------------
$remainPercent = if ($data.context_window.remaining_percentage -ne $null) {
    [int]($data.context_window.remaining_percentage)
} else {
    100
}

# ---------------------------------------------------------------------------
# 模型名稱（簡化顯示）
# ---------------------------------------------------------------------------
$modelId = if ($data.model.id) { $data.model.id } else { "" }
$modelDisplay = switch -Wildcard ($modelId) {
    "*opus-4-6*"   { "Opus 4.6"; break }
    "*opus-4-5*"   { "Opus 4.5"; break }
    "*sonnet-4-6*" { "Sonnet 4.6"; break }
    "*sonnet-4-5*" { "Sonnet 4.5"; break }
    "*sonnet-4*"   { "Sonnet 4"; break }
    "*opus-4*"     { "Opus 4"; break }
    "*haiku-4-5*"  { "Haiku 4.5"; break }
    "*sonnet-3-7*" { "Sonnet 3.7"; break }
    "*sonnet-3-5*" { "Sonnet 3.5"; break }
    "*opus-3*"     { "Opus 3"; break }
    default {
        if ($data.model.display_name) {
            $data.model.display_name
        } elseif ($data.model.id) {
            $data.model.id
        } else {
            "Model Unknown"
        }
    }
}

# ---------------------------------------------------------------------------
# Rate-limit：從 API 快取取得 (每 15 秒更新)
# ---------------------------------------------------------------------------
function Convert-SecsToDhm($total) {
    if ($total -le 0) { return "0m" }
    $d = [math]::Floor($total / 86400)
    $h = [math]::Floor(($total % 86400) / 3600)
    $m = [math]::Floor(($total % 3600) / 60)
    $out = ""
    if ($d -gt 0) { $out += "${d}d" }
    if ($h -gt 0) { $out += "${h}h" }
    if ($m -gt 0) { $out += "${m}m" }
    if ($out -eq "") { $out = "0m" }
    return $out
}

$cachePath = Join-Path $env:USERPROFILE ".claude\rate-limit-cache.json"
$cacheMaxAgeSec = 15
$rateSegment = ""

# 判斷快取是否過期
$needRefresh = $true
if (Test-Path $cachePath) {
    $cacheAge = (Get-Date) - (Get-Item $cachePath).LastWriteTime
    if ($cacheAge.TotalSeconds -lt $cacheMaxAgeSec) {
        $needRefresh = $false
    }
}

# 過期則呼叫 API 更新快取
if ($needRefresh) {
    try {
        $credPath = Join-Path $env:USERPROFILE ".claude\.credentials.json"
        if (Test-Path $credPath) {
            $cred = Get-Content $credPath -Raw | ConvertFrom-Json
            $token = $cred.claudeAiOauth.accessToken
            $raw = & curl.exe -s --max-time 5 `
                -H "Authorization: Bearer $token" `
                -H "anthropic-beta: oauth-2025-04-20" `
                "https://api.anthropic.com/api/oauth/usage" 2>$null
            if ($raw) {
                [System.IO.File]::WriteAllText($cachePath, $raw)
            }
        }
    } catch { }
}

# 讀取快取並組合 rate-limit 顯示
if (Test-Path $cachePath) {
    try {
        $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
        $now = Get-Date

        $pct5h = ""
        $rem5h = ""
        if ($cache.five_hour) {
            $pct5h = 100 - [int]($cache.five_hour.utilization)
            $resetTime = [DateTimeOffset]::Parse($cache.five_hour.resets_at).LocalDateTime
            $secsLeft = [math]::Max(0, ($resetTime - $now).TotalSeconds)
            $rem5h = "(" + (Convert-SecsToDhm $secsLeft) + ")"
        }

        $pct7d = ""
        $rem7d = ""
        if ($cache.seven_day) {
            $pct7d = 100 - [int]($cache.seven_day.utilization)
            $resetTime = [DateTimeOffset]::Parse($cache.seven_day.resets_at).LocalDateTime
            $secsLeft = [math]::Max(0, ($resetTime - $now).TotalSeconds)
            $rem7d = "(" + (Convert-SecsToDhm $secsLeft) + ")"
        }

        if ($pct5h -ne "" -and $pct7d -ne "") {
            $rateSegment = "5h:${pct5h}%${rem5h} 7d:${pct7d}%${rem7d}"
        }
    } catch { }
}

# ---------------------------------------------------------------------------
# Git 分支
# ---------------------------------------------------------------------------
$gitInfo = ""
try {
    Push-Location $cwd
    $gitDir = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -eq 0) {
        $branch = git --no-optional-locks symbolic-ref --short HEAD 2>$null
        if ($branch) {
            $gitInfo = " git:($branch)"
        }
    }
    Pop-Location
} catch {
    if ((Get-Location).Path -ne $cwd) {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# 組合輸出
# ---------------------------------------------------------------------------
if ($rateSegment) {
    Write-Host -NoNewline "Remaining: ${remainPercent}% | $rateSegment | $modelDisplay | ${currentDir}${gitInfo}"
} else {
    Write-Host -NoNewline "Remaining: ${remainPercent}% | $modelDisplay | ${currentDir}${gitInfo}"
}
