param(
  [ValidateSet("generic", "baseline", "avx512")]
  [string[]] $Variants = @("generic", "baseline", "avx512"),
  [string] $JdkIncludePath = $(if ($env:JVM_INCLUDE_PATH) { $env:JVM_INCLUDE_PATH } elseif ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "include" } else { "" }),
  [string] $DeployRoot = $(Join-Path $PSScriptRoot "..\..\libs\native\jhdf5")
)

$ErrorActionPreference = "Stop"

if (-not $JdkIncludePath -or -not (Test-Path $JdkIncludePath) -or -not (Test-Path (Join-Path $JdkIncludePath "win32"))) {
  throw "JDK JNI include path is missing. Set JAVA_HOME or JVM_INCLUDE_PATH before running this script."
}

$archive = Join-Path $PSScriptRoot "CMake-hdf5-1.10.11.zip"
if (-not (Test-Path $archive)) {
  throw "Missing $archive. Download the official HDF5 CMake archive from https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.11/src/CMake-hdf5-1.10.11.zip"
}

$initialCl = $env:CL

function Invoke-NativeTool {
  param([string] $Command, [string[]] $Arguments)
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

foreach ($variant in $Variants) {
  $env:POSTFIX = $variant
  $env:CMAKE_PRESET = "hict-StdShar-MSVC-notest"
  switch ($variant) {
    "generic" { $env:CL = "/O2 /GL $initialCl" }
    "baseline" { $env:CL = "/O2 /arch:AVX2 /GL $initialCl" }
    "avx512" { $env:CL = "/O2 /arch:AVX512 /GL $initialCl" }
  }

  Write-Host "[jhdf5] Preparing Windows amd64 $variant variant"
  bash (Join-Path $PSScriptRoot "prepare_winbuild.sh")

  $sourceDir = Join-Path $PSScriptRoot "build\CMake-hdf5-1.10.11-$variant\hdf5-1.10.11"
  if (-not (Test-Path $sourceDir)) {
    throw "Prepared HDF5 source directory was not found: $sourceDir"
  }

  Push-Location $sourceDir
  try {
    Invoke-NativeTool "cmake" @("--workflow", "--preset", "hict-StdShar-MSVC-notest", "--fresh")
  } finally {
    Pop-Location
  }

  $binaryDir = Join-Path $sourceDir "build110\hict-StdShar-MSVC\bin\Release"
  $buildRoot = Join-Path $sourceDir "build110\hict-StdShar-MSVC"
  $deployDir = Join-Path $DeployRoot "amd64-Windows-$variant"
  New-Item -ItemType Directory -Force -Path $deployDir | Out-Null
  Get-ChildItem $binaryDir -Filter "*.dll" | Copy-Item -Destination $deployDir -Force

  $builtPluginCount = 0
  $builtPluginDirs = @(
    (Join-Path $buildRoot "plugins\Release"),
    (Join-Path $buildRoot "plugins"),
    $binaryDir
  )
  foreach ($pluginDir in $builtPluginDirs) {
    if (Test-Path $pluginDir) {
      foreach ($plugin in Get-ChildItem $pluginDir -File | Where-Object { $_.Name -like "libh5*.dll" -or $_.Name -like "blosc*.dll" -or $_.Name -like "libblosc*.dll" }) {
        Copy-Item $plugin.FullName -Destination $deployDir -Force
        $builtPluginCount += 1
      }
    }
  }

  $legacyPluginDir = Join-Path $DeployRoot "amd64-Windows"
  if ($builtPluginCount -eq 0 -and (Test-Path $legacyPluginDir)) {
    Write-Host "[jhdf5] Built HDF5 compression plugins were not found; using legacy plugin copies from $legacyPluginDir"
    Get-ChildItem $legacyPluginDir -Filter "libh5*.dll" -File | Copy-Item -Destination $deployDir -Force
    Get-ChildItem $legacyPluginDir -Filter "*blosc*.dll" -File | Copy-Item -Destination $deployDir -Force
  } else {
    Write-Host "[jhdf5] Deployed $builtPluginCount freshly built HDF5 compression plugin DLLs to $deployDir"
  }

  if (Test-Path (Join-Path $deployDir "hdf5_java.dll")) {
    Copy-Item (Join-Path $deployDir "hdf5_java.dll") (Join-Path $deployDir "jhdf5.dll") -Force
  }
  Write-Host "[jhdf5] Deployed Windows amd64 $variant DLLs to $deployDir"
}
