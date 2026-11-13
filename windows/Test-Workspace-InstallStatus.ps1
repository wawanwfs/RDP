$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Workspace-InstallStatus.ps1')

function Assert-Equal($Actual, $Expected, $Label) {
  if ($Actual -ne $Expected) { throw "$Label expected [$Expected], got [$Actual]" }
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('wfs-install-test-' + [guid]::NewGuid().ToString('N'))
New-Item -Path $scratch -ItemType Directory | Out-Null
$previousStatusDir = $env:WFS_INSTALL_STATUS_DIR
$previousWorkerDir = $env:WFS_INSTALL_WORKER_DIR
$env:WFS_INSTALL_STATUS_DIR = $scratch
$env:WFS_INSTALL_WORKER_DIR = $scratch
try {
  # Use local PowerShell children, not the real vendor installers or secrets.
  $child = Join-Path $PSHOME 'pwsh.exe'
  $childFlags = @('-NoProfile', '-NonInteractive', '-Command')
  Assert-Equal (Invoke-BoundedInstaller $child ($childFlags + 'exit 17') 10) 17 'Native exit code'
  Invoke-OptionalInstall '9Router' {
    'ROUTER_READY=1' | Set-Content (Join-Path $scratch 'env.txt')
  }
  Invoke-OptionalInstall 'OmniRoute' {
    Invoke-BoundedInstaller $child ($childFlags + 'Start-Sleep -Seconds 45') 2 | Out-Null
  }
  Assert-Equal (Get-WorkspaceInstallState 'OmniRoute') 'TimedOut' 'Hung native installer state'
  Assert-Equal (Get-WorkspaceAppStatus 'OmniRoute' $true $true) '⏱️ Installer timed out' 'Partial shim must not count as ready'
  Assert-Equal (Get-Content (Join-Path $scratch 'env.txt.completed')) 'ROUTER_READY=1' 'Completed installer checkpoint'
  Invoke-OptionalInstall 'Codex CLI' { throw 'Injected installer failure' }
  Invoke-OptionalInstall 'Claude Code' { }
  Assert-Equal (Get-WorkspaceAppStatus 'Codex CLI' $true $true) '❌ Install failed — see installer logs' 'Failed install'
  Assert-Equal (Get-WorkspaceAppStatus 'Claude Code' $true $true) '✅ Ready' 'Next installer still runs'
  Assert-Equal (Get-WorkspaceAppStatus 'Claude Code' $true $false) '⚠️ Executable not verified' 'Attempt alone is not success'
  Set-WorkspaceInstallState 'Node.js LTS' 'Running'
  Assert-Equal (Get-WorkspaceAppStatus 'Node.js LTS' $true $false 'TimedOut') '⚠️ Installation interrupted — not verified' 'Interrupted installer'
  Assert-Equal (Get-WorkspaceAppStatus 'OpenCode' $true $false 'TimedOut') '⚠️ Not attempted or not recorded — see group log' 'Worker stopped before app'
  Assert-Equal (Get-WorkspaceAppStatus 'OpenCode' $false $false 'TimedOut') '⏭️ Skipped' 'Unselected app'

  # The YAML contains indented literal run blocks. Parse every one as PowerShell,
  # replacing GitHub expressions with an inert value before calling the parser.
  $workflow = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.github/workflows/windows-remote-workspace.yml') -Raw
  $blocks = [regex]::Matches($workflow, '(?m)^        run: \|\r?\n((?:(?: {10}[^\r\n]*| *)\r?\n)+)')
  if ($blocks.Count -lt 15) { throw "Expected workspace run blocks, found $($blocks.Count)" }
  foreach ($block in $blocks) {
    $source = $block.Groups[1].Value -replace '(?m)^ {10}', '' -replace '\$\{\{[^\r\n]*?\}\}', 'wfs-test'
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) { throw ($errors | Out-String) }
  }
  Write-Host "PASS: installer timeouts, failure isolation, Summary states, and $($blocks.Count) PowerShell run blocks."
} finally {
  $env:WFS_INSTALL_STATUS_DIR = $previousStatusDir
  $env:WFS_INSTALL_WORKER_DIR = $previousWorkerDir
  Remove-Item -LiteralPath $scratch -Recurse -Force
}
