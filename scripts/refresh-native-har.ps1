<#
Consume only rd-engine's owning NAPI build. Never rebuild or hand-edit a HAR here.
#>
param(
  [string]$EngineRoot = $(if ($env:RD_ENGINE_ROOT) { $env:RD_ENGINE_ROOT } else { Join-Path $PSScriptRoot '..\..\rd-engine' }),
  [string]$SourceHar,
  [string]$Ohpm,
  [switch]$KeepModules
)

$ErrorActionPreference = 'Stop'
$AppRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Verifier = Join-Path $AppRoot 'scripts\verify-native-har.py'
$TargetHar = Join-Path $AppRoot 'rustdesk-ohrs.har'

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
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }
  throw 'ohpm was not found. Install DevEco Studio or provide -Ohpm.'
}

function Find-Python {
  foreach ($candidate in @($env:PYTHON, 'python3', 'python')) {
    if (-not $candidate) {
      continue
    }
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }
  throw 'python 3 is required to verify the HAR; set PYTHON to a python executable.'
}

# build-har.sh stages these outputs here, independently of Cargo's cache/target settings.
if (-not $SourceHar) {
  $SourceHar = $env:NATIVE_HAR_PATH
}
if (-not $SourceHar) {
  $SourceHar = Join-Path $EngineRoot 'native\ohos_napi\target\package.har'
}
if (-not (Test-Path -LiteralPath $SourceHar -PathType Leaf)) {
  throw "Missing native HAR: $SourceHar`nBuild it first:`n  cd $EngineRoot`n  bash native/ohos_napi/build-har.sh"
}
$SourceHar = (Resolve-Path -LiteralPath $SourceHar).Path
$SourceProvenance = if ($env:NATIVE_PROVENANCE_PATH) {
  $env:NATIVE_PROVENANCE_PATH
}
else {
  Join-Path (Split-Path -Parent $SourceHar) 'release-provenance.json'
}

$rootPackage = Get-Content -Raw -LiteralPath (Join-Path $AppRoot 'oh-package.json5') | ConvertFrom-Json
if ($rootPackage.dependencies.'rustdesk-ohrs' -ne 'file:./rustdesk-ohrs.har') {
  throw 'oh-package.json5 must depend on "rustdesk-ohrs": "file:./rustdesk-ohrs.har".'
}
$python = Find-Python
$verifyArgs = @($Verifier, '--har', $SourceHar, '--sidecar', $SourceProvenance)
if ($env:RD_ENGINE_SHA) {
  $verifyArgs += @('--expected-engine-sha', $env:RD_ENGINE_SHA)
}
if ($env:RD_ENGINE_HAR_VERSION) {
  $verifyArgs += @('--expected-package-version', $env:RD_ENGINE_HAR_VERSION)
}
# Schema 2 records a commit/dirty flag, not a working-tree freshness receipt or ABI proof.
& $python @verifyArgs
if ($LASTEXITCODE -ne 0) {
  throw "HAR verification failed with exit code $LASTEXITCODE."
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

Write-Host "Refreshed $TargetHar from $SourceHar"
