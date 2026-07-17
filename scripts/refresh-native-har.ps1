param(
  [string]$NativeRoot = (Join-Path $PSScriptRoot '..\..\rustdesk_native_har'),
  [string]$Ohpm,
  [switch]$KeepModules
)

$ErrorActionPreference = 'Stop'

$AppRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$NativeRoot = (Resolve-Path $NativeRoot).Path
$SourceHar = Join-Path $NativeRoot 'package.har'
$TargetHar = Join-Path $AppRoot 'rustdesk-ohrs.har'
$ModuleJsonSource = Join-Path $NativeRoot 'package\build\default\intermediates\merge_profile\default\module.json'

function Find-Ohpm {
  if ($Ohpm) {
    return $Ohpm
  }

  $command = Get-Command ohpm -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $devecoHome = if ($env:DEVECO_HOME) { $env:DEVECO_HOME } else { 'C:\Program Files\Huawei\DevEco Studio' }
  $candidates = @(
    (Join-Path $devecoHome 'tools\ohpm\bin\ohpm.bat'),
    (Join-Path $devecoHome 'tools\ohpm\bin\ohpm')
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw 'ohpm was not found. Install DevEco Studio or provide -Ohpm.'
}

if (-not (Test-Path -LiteralPath $SourceHar)) {
  throw "Missing native HAR: $SourceHar`nBuild it first with rustdesk_native_har\scripts\build-har.ps1."
}

$Ohpm = Find-Ohpm
Copy-Item -LiteralPath $SourceHar -Destination $TargetHar -Force

if (-not $KeepModules) {
  foreach ($path in @(
    (Join-Path $AppRoot 'oh_modules'),
    (Join-Path $AppRoot 'entry\oh_modules')
  )) {
    if (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
}

Push-Location $AppRoot
try {
  & $Ohpm install
  if ($LASTEXITCODE -ne 0) {
    throw "ohpm install failed with exit code $LASTEXITCODE."
  }

  Push-Location (Join-Path $AppRoot 'entry')
  try {
    & $Ohpm install
    if ($LASTEXITCODE -ne 0) {
      throw "entry ohpm install failed with exit code $LASTEXITCODE."
    }
  }
  finally {
    Pop-Location
  }
}
finally {
  Pop-Location
}

# Hvigor probes unpacked HAR dependencies for module.json even when the package
# itself is authored with module.json5. Copy the merged profile output into each
# installed rustdesk-ohrs dependency if it exists.
if (Test-Path -LiteralPath $ModuleJsonSource) {
  $moduleRoots = @(
    (Join-Path $AppRoot 'oh_modules\.ohpm'),
    (Join-Path $AppRoot 'entry\oh_modules\.ohpm')
  )

  foreach ($moduleRoot in $moduleRoots) {
    if (-not (Test-Path -LiteralPath $moduleRoot)) {
      continue
    }

    Get-ChildItem -LiteralPath $moduleRoot -Directory -Recurse -Filter 'main' |
      Where-Object { $_.FullName -match 'rustdesk-ohrs[\\/]src[\\/]main$' } |
      ForEach-Object {
        Copy-Item -LiteralPath $ModuleJsonSource -Destination (Join-Path $_.FullName 'module.json') -Force
      }
  }
}

Write-Host "Refreshed $TargetHar from $SourceHar"
