param(
  [ValidateSet("generic", "avx2", "baseline", "avx512")]
  [string[]] $Variants = @("generic", "avx2"),
  [string] $BuildRoot = $(Join-Path $PSScriptRoot "build")
)

$ErrorActionPreference = "Stop"

function Invoke-DeveloperCommandPromptEnvironment {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe was not found. Visual Studio Build Tools are required to run tests." 
  }

  $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $vsPath) {
    throw "No Visual Studio installation with MSVC x64 tools was found." 
  }

  $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
  if (-not (Test-Path $vcvars)) {
    throw "vcvars64.bat was not found at $vcvars." 
  }

  $envDump = cmd.exe /s /c "`"$vcvars`" >nul && set"
  if ($LASTEXITCODE -ne 0) {
    throw "vcvars64.bat failed with exit code $LASTEXITCODE while preparing test environment." 
  }

  foreach ($line in ($envDump -split "`r?`n")) {
    if ($line -match "^[A-Za-z0-9_]+=" ) {
      $name, $value = $line.Split("=", 2)
      Set-Item -Path "Env:$name" -Value $value
    }
  }
}

function Resolve-TestBuildDirectory {
  param([string] $Variant)

  $outputVariant = $Variant
  if ($Variant -eq "baseline") {
    $outputVariant = "avx2"
  }

  $buildRoot = Join-Path $BuildRoot "CMake-hdf5-1.10.11-${outputVariant}\hdf5-1.10.11"
  $candidatePresets = @(
    "hict-StdShar-MSVC",
    "ci-StdShar-MSVC",
    "hict-StdShar-MSVC-noexamples",
    "ci-StdShar-MSVC-noexamples",
    "hict-StdShar-MSVC-notest",
    "ci-StdShar-MSVC-notest"
  )
  foreach ($candidate in $candidatePresets) {
    $testDir = Join-Path $buildRoot "build110\${candidate}"
    if (Test-Path $testDir) {
      return $testDir
    }
  }
  return Join-Path $buildRoot "build110\hict-StdShar-MSVC"
}

function Run-TestPreset {
  param([string] $Variant)

  $ctestExe = Get-Command ctest -ErrorAction SilentlyContinue
  if (-not $ctestExe) {
    throw "ctest was not found in PATH. Install/update Visual Studio/CMake toolchain before running tests." 
  }

  $testDir = Resolve-TestBuildDirectory -Variant $Variant

  if (-not (Test-Path $testDir)) {
    Write-Host "[jhdf5-tests] Test directory not found for variant '${Variant}' (expected: ${testDir}). Skipping." 
    return
  }

  Write-Host "[jhdf5-tests] Running Windows HDF5 tests for variant '${Variant}' in ${testDir}"
  Push-Location $testDir
  try {
    & $ctestExe.Source --output-on-failure -j 2
    if ($LASTEXITCODE -ne 0) {
      throw "ctest failed for variant '${Variant}' with exit code ${LASTEXITCODE}."
    }
    Write-Host "[jhdf5-tests] Variant '${Variant}' passed."
  } finally {
    Pop-Location
  }
}

Import-DeveloperCommandPromptEnvironment

$hasFailure = $false
foreach ($variant in $Variants) {
  try {
    Run-TestPreset -Variant $variant
  } catch {
    $hasFailure = $true
    Write-Error $_
  }
}

if ($hasFailure) {
  throw "At least one Windows HDF5 test run failed."
}
