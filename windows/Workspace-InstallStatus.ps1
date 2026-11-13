# Shared by the Windows workspace installer and dashboard. Only fixed state
# labels (never installer output or exception text) are persisted for Summary.
function Set-WorkspaceInstallState {
  param([string] $Name, [ValidateSet('Running', 'Attempted', 'Failed', 'TimedOut')] [string] $State)
  if (-not $env:WFS_INSTALL_STATUS_DIR) { return }
  if ($Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9 .-]*$') { throw "Invalid application status name: $Name" }
  $path = Join-Path $env:WFS_INSTALL_STATUS_DIR "$Name.status"
  try {
    Set-Content -LiteralPath "$path.tmp" -Value $State -Encoding utf8 -ErrorAction Stop
    Move-Item -LiteralPath "$path.tmp" -Destination $path -Force -ErrorAction Stop
  } catch {
    Write-Warning "Could not record installer state for $Name. See the installer logs."
  }
}

function Get-WorkspaceInstallState {
  param([string] $Name)
  if (-not $env:WFS_INSTALL_STATUS_DIR) { return }
  if ($Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9 .-]*$') { throw "Invalid application status name: $Name" }
  $path = Join-Path $env:WFS_INSTALL_STATUS_DIR "$Name.status"
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    (Get-Content -LiteralPath $path -Raw).Trim()
  }
}

function Get-WorkspaceAppStatus {
  param([string] $Name, [bool] $Requested, [bool] $Detected, [string] $GroupState = '')
  if (-not $Requested) { return '⏭️ Skipped' }
  switch (Get-WorkspaceInstallState $Name) {
    'TimedOut' { return '⏱️ Installer timed out' }
    'Failed' { return '❌ Install failed — see installer logs' }
    'Running' { return '⚠️ Installation interrupted — not verified' }
    'Attempted' { if ($Detected) { return '✅ Ready' }; return '⚠️ Executable not verified' }
  }
  if ($GroupState -in @('TimedOut', 'Failed')) { return '⚠️ Not attempted or not recorded — see group log' }
  if ($Detected) { return '✅ Ready' }
  return '⚠️ Check logs'
}

function Invoke-OptionalInstall {
  param(
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [scriptblock] $Action
  )
  $clock = [Diagnostics.Stopwatch]::StartNew()
  Set-WorkspaceInstallState $Name 'Running'
  Write-Host "⚙️ Starting optional installation: $Name"
  try {
    & $Action
    if ($env:WFS_INSTALL_WORKER_DIR) {
      foreach ($file in @('env.txt', 'path.txt')) {
        $source = Join-Path $env:WFS_INSTALL_WORKER_DIR $file
        if (Test-Path -LiteralPath $source -PathType Leaf) {
          $checkpoint = "$source.completed"
          Copy-Item -LiteralPath $source -Destination "$checkpoint.tmp" -Force -ErrorAction Stop
          Move-Item -LiteralPath "$checkpoint.tmp" -Destination $checkpoint -Force -ErrorAction Stop
        }
      }
    }
    Set-WorkspaceInstallState $Name 'Attempted'
    Write-Host "🏁 Finished optional installation attempt: $Name"
  } catch [TimeoutException] {
    Set-WorkspaceInstallState $Name 'TimedOut'
    Write-Warning "⚠️ Optional installation timed out for ${Name}: $($_.Exception.Message)"
  } catch {
    Set-WorkspaceInstallState $Name 'Failed'
    Write-Warning "⚠️ Optional installation failed for ${Name}: $($_.Exception.Message)"
  } finally {
    Write-Host ("⏱️ TIME {0}: {1:N1}s" -f $Name, $clock.Elapsed.TotalSeconds)
  }
}

function Invoke-BoundedInstaller {
  param([string] $FilePath, [string[]] $Arguments, [int] $TimeoutSeconds = 300, [pscredential] $Credential = $null)
  $logBase = Join-Path $env:TEMP ('rdp-installer-' + [guid]::NewGuid().ToString('N'))
  $identity = @{}
  if ($Credential) { $identity = @{ Credential = $Credential; LoadUserProfile = $true; WorkingDirectory = $env:SystemRoot } }
  $process = $null
  $PSNativeCommandUseErrorActionPreference = $false
  try {
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -NoNewWindow `
      -RedirectStandardOutput "$logBase.out" -RedirectStandardError "$logBase.err" @identity
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Host
      if (-not $process.WaitForExit(5000)) {
        try { $process.Kill($true) } catch { if (-not $process.HasExited) { throw } }
      }
      throw [TimeoutException]::new("Installer exceeded $TimeoutSeconds seconds; process tree terminated.")
    }
    return [int]$process.ExitCode
  } finally {
    foreach ($file in @("$logBase.out", "$logBase.err")) {
      if (Test-Path -LiteralPath $file) {
        Get-Content -LiteralPath $file -Tail 60 -ErrorAction SilentlyContinue | Out-Host
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
      }
    }
    if ($process) { $process.Dispose() }
  }
}
