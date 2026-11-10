#Requires -Version 7.0
<#
 WFS Remote Workspaces: signed MetaTrader Windows installer.
 Shared by the Windows remote workflow and the native Windows smoke test.
 No credentials, EA, orders, or broker login are configured.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('mt4','mt5')] [string] $Version,
  [int] $TimeoutSeconds = 300,
  [switch] $AllowInteractiveFallback
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = @{
  mt4 = 'https://download.terminal.free/cdn/web/exness.technologies.ltd/mt4/exness4setup.exe'
  mt5 = 'https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe'
}
$exeName = if ($Version -eq 'mt4') { 'terminal.exe' } else { 'terminal64.exe' }
$folderPattern = if ($Version -eq 'mt4') { '(?i)(exness|meta.?trader\s*4|mt4)' } else { '(?i)(meta.?trader\s*5|mt5)' }
$rejectPattern = if ($Version -eq 'mt4') { '(?i)(meta.?trader\s*5|mt5)' } else { '(?i)(meta.?trader\s*4|mt4)' }
$title = if ($Version -eq 'mt4') { 'MetaTrader 4' } else { 'MetaTrader 5' }

function Find-Terminal {
  $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
  $roots = @($env:ProgramFiles, $programFilesX86)
  foreach ($root in ($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique)) {
    foreach ($folder in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
      if ($folder.Name -notmatch $folderPattern -or $folder.Name -match $rejectPattern) { continue }
      $candidates = @((Join-Path $folder.FullName $exeName))
      $candidates += @(Get-ChildItem -LiteralPath $folder.FullName -Filter $exeName -File -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
      foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        if ((Get-Item -LiteralPath $candidate).Length -lt 500000) { continue }
        return (Resolve-Path -LiteralPath $candidate).Path
      }
    }
  }
  return $null
}

$terminal = Find-Terminal
if (-not $terminal) {
  $installer = Join-Path ([IO.Path]::GetTempPath()) ("wfs-$Version-" + [guid]::NewGuid().ToString('N') + ".exe")
  try {
    Write-Host "[WFS Trading] Downloading $title from vendor/broker-linked HTTPS CDN"
    Invoke-WebRequest -Uri $source[$Version] -OutFile $installer -TimeoutSec 180 -MaximumRedirection 5
    $len = (Get-Item -LiteralPath $installer).Length
    if ($len -lt 1000000 -or $len -gt 100000000) { throw "Unexpected installer size: $len" }
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid') { throw "$title installer signature: $($signature.Status)" }
    if ($signature.SignerCertificate.Subject -notmatch '(?i)(metaquotes|exness)') {
      throw "$title unexpected Authenticode signer: $($signature.SignerCertificate.Subject)"
    }
    Write-Host "[WFS Trading] Authenticode valid; installer SHA256: $((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash)"
    $installExitCode = $null
    $mutex = [Threading.Mutex]::new($false, 'Global\RdpWorkflowWingetInstall')
    $locked = $false
    try {
      try { $locked = $mutex.WaitOne(600000) }
      catch [Threading.AbandonedMutexException] { $locked = $true }
      if (-not $locked) { throw 'Could not acquire installer lock' }
      $process = Start-Process -FilePath $installer -ArgumentList @('/auto') -PassThru
      try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
          & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Host
          throw "$title installer timeout"
        }
        $process.WaitForExit()
        $installExitCode = $process.ExitCode
      } finally { $process.Dispose() }
    } finally {
      if ($locked) { $mutex.ReleaseMutex() }
      $mutex.Dispose()
    }
    # The web bootstrap can hand execution to a child or exit code 1 when no
    # interactive session is present. Neither an exit code nor a process name
    # proves installation. Poll for the exact terminal before deciding.
    for ($attempt = 0; $attempt -lt 15; $attempt++) {
      $terminal = Find-Terminal
      if ($terminal) { break }
      Start-Sleep -Seconds 3
    }
    if (-not $terminal) {
      if (-not $AllowInteractiveFallback) {
        throw "$title unattended setup exited $installExitCode and did not produce $exeName"
      }
      # Preserve the *already signed and verified* installer on the disposable
      # runner, and expose a visible shortcut for the first interactive RDP
      # login. Do not assert that MT4/MT5 is installed.
      $pendingDir = Join-Path $env:ProgramData "WFS-Remote-Workspaces\PendingTrading\$Version"
      New-Item -Path $pendingDir -ItemType Directory -Force | Out-Null
      $pendingExe = Join-Path $pendingDir ("setup-$Version.exe")
      Copy-Item -LiteralPath $installer -Destination $pendingExe -Force
      $newSignature = Get-AuthenticodeSignature -LiteralPath $pendingExe
      if ($newSignature.Status -ne 'Valid') { throw 'Staged installer signature verification failed' }
      $commonDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
      if (-not $commonDesktop) { throw 'Public Desktop path is unavailable' }
      $shortcut = Join-Path $commonDesktop "Install $title (WFS).lnk"
      $shell = New-Object -ComObject WScript.Shell
      $link = $shell.CreateShortcut($shortcut)
      $link.TargetPath = $pendingExe
      $link.WorkingDirectory = $pendingDir
      $link.Description = "Complete the signed $title installer when logged in through RDP"
      $link.Save()
      if (-not (Test-Path -LiteralPath $shortcut)) { throw 'Staged desktop shortcut was not created' }
      $statusVar = if ($Version -eq 'mt4') { 'MT4_INSTALL_STATUS' } else { 'MT5_INSTALL_STATUS' }
      Set-Item -Path "Env:$statusVar" -Value 'PENDING_INTERACTIVE'
      if ($env:GITHUB_ENV) {
        Add-Content -LiteralPath $env:GITHUB_ENV -Value "$statusVar=PENDING_INTERACTIVE" -Encoding utf8
      }
      Write-Warning "$title unattended setup exited $installExitCode. Signed installer staged to Public Desktop; interactive installation is still REQUIRED."
      return [pscustomobject]@{
        Version = $Version
        Verified = $false
        PendingInteractive = $true
        Installer = $pendingExe
        Shortcut = $shortcut
      }
    }
    if ($installExitCode -ne 0) {
      Write-Warning "$title installer returned $installExitCode but the version-matched terminal executable was independently verified."
    }
  } finally {
    Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
  }
}
$sha = (Get-FileHash -LiteralPath $terminal -Algorithm SHA256).Hash
$envName = if ($Version -eq 'mt4') { 'MT4_TERMINAL_EXE' } else { 'MT5_TERMINAL_EXE' }
Set-Item -Path "Env:$envName" -Value $terminal
if ($env:GITHUB_ENV) { Add-Content -LiteralPath $env:GITHUB_ENV -Value "$envName=$terminal" -Encoding utf8 }
Write-Host "[WFS Trading] VERIFIED $title : $terminal (SHA256 $sha)"
[pscustomobject]@{ Version=$Version; Executable=$terminal; Sha256=$sha; Verified=$true }
