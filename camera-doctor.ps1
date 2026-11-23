<#
  EVERGREEN · 摄像头诊断

  用法（在 PowerShell 里，或直接双击 camera-doctor.bat）：
    powershell -NoProfile -ExecutionPolicy Bypass -File camera-doctor.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File camera-doctor.ps1 -Fix

  -Fix  禁用并重新启用摄像头设备（等同设备管理器里的“禁用→启用”），
        可修复 USB 摄像头卡在“被占用 / 无法启动”的状态。需要管理员权限。

  这个脚本只读取系统信息；加 -Fix 才会改动设备状态，不改任何文件。
#>
[CmdletBinding()]
param(
    [switch]$Fix
)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$problems = New-Object System.Collections.ArrayList
$notes = New-Object System.Collections.ArrayList

function Section([string]$title) {
    Write-Host ""
    $line = "── $title " + ("─" * [Math]::Max(0, 56 - $title.Length))
    Write-Host $line -ForegroundColor DarkGray
}
function Ok([string]$text) { Write-Host "  [OK]   $text" -ForegroundColor Green }
function Warn([string]$text) { Write-Host "  [注意] $text" -ForegroundColor Yellow }
function Bad([string]$text) {
    Write-Host "  [问题] $text" -ForegroundColor Red
    [void]$problems.Add($text)
}
function Info([string]$text) { Write-Host "  ·      $text" -ForegroundColor Gray }

Write-Host ""
Write-Host "  EVERGREEN · 摄像头诊断" -ForegroundColor Yellow
Write-Host "  页面里出现 NotReadableError（Could not start video source）时先跑一遍。" -ForegroundColor DarkGray

# ── 1. 系统 ───────────────────────────────────────────────
Section "系统"
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
if ($os) { Info ("{0}  ·  build {1}" -f $os.Caption, $os.BuildNumber) }
if ($cs) {
    Info ("{0} {1}" -f $cs.Manufacturer, $cs.Model)
    if ($cs.Manufacturer -match 'ASUS|ASUSTeK') {
        Info "华硕笔记本：键盘上的 F10 是摄像头开关，指示灯不亮时任何软件都读不到画面。"
        [void]$notes.Add("确认 F10 摄像头开关已经打开（指示灯亮）。")
    }
}

# ── 2. 摄像头设备 ─────────────────────────────────────────
Section "摄像头设备"
$devices = @()
$devices += Get-PnpDevice -Class Camera -ErrorAction SilentlyContinue
$devices += Get-PnpDevice -Class Image -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'cam|摄像' }
$devices = $devices | Where-Object { $_ } | Sort-Object InstanceId -Unique

$presentCameras = @()
if (-not $devices) {
    Bad "系统里没有登记任何摄像头设备。"
    Info "外接摄像头请换一个 USB 口；内置摄像头请检查 BIOS / 设备管理器里是否被禁用。"
} else {
    foreach ($dev in $devices) {
        $status = [string]$dev.Status
        $present = [bool]$dev.Present
        if (-not $present) {
            Warn ("{0} —— 未连接（历史设备）" -f $dev.FriendlyName)
            continue
        }
        if ($status -ne 'OK') {
            Bad ("{0} —— 状态 {1}（驱动没有正常启动）" -f $dev.FriendlyName, $status)
            continue
        }
        Ok ("{0} —— 状态 OK" -f $dev.FriendlyName)
        $presentCameras += $dev
    }
    if (-not $presentCameras) {
        Bad "摄像头设备存在，但没有一台处于可用状态。"
    }
}

# ── 3. Windows 隐私开关 ───────────────────────────────────
Section "Windows 隐私设置"
$webcamRoots = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'; Label = '所有应用（系统级）' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\NonPackaged'; Label = '桌面应用（系统级）' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'; Label = '所有应用（当前用户）' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\NonPackaged'; Label = '桌面应用（当前用户）' }
)
foreach ($root in $webcamRoots) {
    $value = (Get-ItemProperty -Path $root.Path -ErrorAction SilentlyContinue).Value
    if (-not $value) {
        Info ("{0}：未配置（默认允许）" -f $root.Label)
    } elseif ($value -eq 'Allow') {
        Ok ("{0}：允许" -f $root.Label)
    } else {
        Bad ("{0}：{1} —— 浏览器会被挡在系统层面" -f $root.Label, $value)
    }
}
if ($problems.Count -gt 0) {
    Info "打开设置 → 隐私和安全性 → 摄像头，把开关全部打开："
    Info "    start ms-settings:privacy-webcam"
}

# ── 4. 可能占用摄像头的程序 ───────────────────────────────
Section "可能占用摄像头的程序"
$known = @{
    'Weixin'         = '微信'
    'WeChat'         = '微信'
    'WeChatAppEx'    = '微信内置浏览器'
    'ToDesk'         = 'ToDesk 远程控制'
    'SunloginClient' = '向日葵远程控制'
    'obs64'          = 'OBS Studio'
    'obs32'          = 'OBS Studio'
    'wemeetapp'      = '腾讯会议'
    'TencentMeeting' = '腾讯会议'
    'Zoom'           = 'Zoom'
    'Teams'          = 'Microsoft Teams'
    'ms-teams'       = 'Microsoft Teams'
    'DingTalk'       = '钉钉'
    'Feishu'         = '飞书'
    'QQ'             = 'QQ'
    'NVIDIA'         = 'NVIDIA Broadcast / 虚拟摄像头'
    'msedge'         = 'Edge'
    'chrome'         = 'Chrome'
    'firefox'        = 'Firefox'
}
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $known.ContainsKey($_.ProcessName) }
$occupied = $false
if (-not $running) {
    Ok "没有发现常见的摄像头程序在运行"
} else {
    foreach ($group in ($running | Group-Object ProcessName | Sort-Object Name)) {
        $label = $known[$group.Name]
        $count = $group.Count
        Warn ("{0}（{1}）正在运行 · {2} 个进程" -f $label, $group.Name, $count)
        if ($group.Name -in @('Weixin', 'WeChat', 'ToDesk', 'SunloginClient', 'obs64', 'obs32', 'Zoom', 'wemeetapp', 'TencentMeeting', 'ms-teams', 'Teams', 'DingTalk', 'Feishu')) {            $occupied = $true
        }
    }
}
if ($occupied) {
    Info "视频通话、远程控制的「远程摄像头」、OBS 虚拟摄像头会独占设备；先结束它们再试。"
}

# 远程会话提示
$remoteWindows = Get-Process -Name ToDesk, SunloginClient -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle.Trim().Length -gt 0 }
if ($remoteWindows) {
    Warn "检测到远程控制窗口：$((($remoteWindows | ForEach-Object { $_.MainWindowTitle }) -join ' / '))"
    Info "如果对端开启了「摄像头 / 远程摄像头」，本地摄像机会被它占用。"
}

# ── 5. 修复 ───────────────────────────────────────────────
Section "修复"
if ($Fix) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Bad "重置设备需要管理员权限。请右键 PowerShell →「以管理员身份运行」，再执行本脚本 -Fix。"
    } elseif (-not $presentCameras) {
        Bad "没有可重置的摄像头设备。"
    } else {
        foreach ($cam in $presentCameras) {
            $name = $cam.FriendlyName
            $id = $cam.InstanceId
            try {
                Disable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 2
                Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop
                Ok ("已重置：{0}" -f $name)
                Info "等 3–5 秒让驱动重新加载，再回到页面点「重试」。"
            } catch {
                Bad ("重置失败：{0} —— {1}" -f $name, $_.Exception.Message)
            }
        }
    }
} else {
    Info "如果上面都正常，但页面仍然报 NotReadableError，加 -Fix 重置一次设备："
    Info "    powershell -NoProfile -ExecutionPolicy Bypass -File camera-doctor.ps1 -Fix"
}

# ── 6. 结论 ───────────────────────────────────────────────
Section "结论"
if ($problems.Count -eq 0) {
    Ok "没有发现系统层面的问题。"
} else {
    foreach ($p in $problems) { Write-Host "  ! $p" -ForegroundColor Red }
}
if ($notes.Count -gt 0) {
    Write-Host ""
    foreach ($n in $notes) { Write-Host "  → $n" -ForegroundColor Yellow }
}
Write-Host ""
Info "仍然不行时的排查顺序：F10 摄像头开关 → 关掉占用程序 → Windows 隐私设置 → 本脚本 -Fix → 重装摄像头驱动。"
Write-Host ""

if ($problems.Count -gt 0 -or $occupied) { exit 1 }
exit 0
