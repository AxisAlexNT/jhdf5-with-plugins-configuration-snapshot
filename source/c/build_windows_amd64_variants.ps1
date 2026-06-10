param(
  [ValidateSet("generic", "avx2", "baseline", "avx512")]
  [string[]] $Variants = @("generic", "avx2", "avx512"),
  [string] $JdkIncludePath = $(if ($env:JVM_INCLUDE_PATH) { $env:JVM_INCLUDE_PATH } elseif ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "include" } else { "" }),
  [string] $DeployRoot = $(Join-Path $PSScriptRoot "..\..\libs\native\jhdf5"),
  [bool] $RunTests = $false
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

function Import-DeveloperCommandPromptEnvironment {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe was not found. Visual Studio Build Tools are required for the Windows JHDF5 build."
  }

  $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (-not $vsPath) {
    throw "No Visual Studio installation with MSVC x64 tools was found."
  }

  $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
  if (-not (Test-Path $vcvars)) {
    throw "vcvars64.bat was not found at $vcvars."
  }

  $env:VSCMD_SKIP_SENDTELEMETRY = "1"
  $envDump = cmd.exe /s /c "`"$vcvars`" >nul && set"
  if ($LASTEXITCODE -ne 0) {
    throw "vcvars64.bat failed with exit code $LASTEXITCODE."
  }

  foreach ($line in ($envDump -split "`r?`n")) {
    if ($line -match "^[A-Za-z0-9_]+=") {
      $name, $value = $line.Split("=", 2)
      Set-Item -Path "Env:$name" -Value $value
    }
  }
}

Import-DeveloperCommandPromptEnvironment

function Invoke-NativeTool {
  param([string] $Command, [string[]] $Arguments)
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Run-Hdf5TestSuite {
  param([string] $BuildRoot, [string] $Variant)

  $ctestExe = Get-Command ctest -ErrorAction SilentlyContinue
  if (-not $ctestExe) {
    throw "ctest was not found in PATH. HDF5 test execution is enabled by default; install/update CMake tools."
  }

  try {
    Invoke-NativeTool "ctest" @("--test-dir", $BuildRoot, "--output-on-failure", "-j", "2")
  } catch {
    Write-Warning "Tests for variant '$Variant' reported failures; native binaries were built and kept for packaging: $($_.Exception.Message)"
  }
}

function Normalize-CMakePreset {
  param([string] $Preset)

  $normalized = $Preset
  $normalized = $normalized.Trim('-')
  return $normalized
}

function Get-CMakePresetList {
  param(
    [string] $SourceDir,
    [string] $SectionName
  )

  $output = & cmake -S "$SourceDir" --list-presets 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "cmake --list-presets returned non-zero exit code ($LASTEXITCODE) while reading presets from $SourceDir"
  }

  $inSection = $false
  $result = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($output -split "`r?`n")) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "Available $SectionName presets:") {
      $inSection = $true
      continue
    }
    if ($inSection) {
      if ($trimmed -match '^"(.+)"$') {
        [void]$result.Add($Matches[1])
      } elseif ($trimmed -and ($trimmed -notmatch '^\s*".*"$')) {
        break
      }
    }
  }
  return $result
}

function Resolve-CMakePreset {
  param([string] $Preset, [string] $SourceDir)

  $workflowPresets = Get-CMakePresetList -SourceDir $SourceDir -SectionName "workflow"
  $configurePresets = Get-CMakePresetList -SourceDir $SourceDir -SectionName "configure"

  $script:USE_CMAKE_WORKFLOW = $workflowPresets.Count -gt 0
  if (-not $script:USE_CMAKE_WORKFLOW -and $configurePresets.Count -gt 0) {
    Write-Host "[jhdf5] Workflow preset section is unavailable; falling back to configure/build preset sequence."
  }

  $candidatePresets = @(
    $Preset,
    ($Preset -replace '^hict-', 'ci-'),
    ($Preset -replace '^ci-', 'hict-'),
    ($Preset -replace '-notest-noexamples', ''),
    ($Preset -replace '-notest', ''),
    ($Preset -replace '-noexamples', '')
  )
  $candidatePresets = $candidatePresets | Where-Object { $_ } | Select-Object -Unique

  $availablePresets = if ($script:USE_CMAKE_WORKFLOW) { $workflowPresets } else { $configurePresets }
  foreach ($candidate in $candidatePresets) {
    $candidate = Normalize-CMakePreset -Preset $candidate
    if ($availablePresets.Contains($candidate)) {
      return $candidate
    }
    # In configure-only environments, allow workflow-style names to resolve to configure base names.
    $workflowCandidate = $candidate -replace '^hict-|^ci-'
    $configureCandidate = ($candidate -replace '-notest-noexamples', '' -replace '-notest', '' -replace '-noexamples', '')
    if (-not $script:USE_CMAKE_WORKFLOW) {
      if ($configureCandidate -ne $candidate -and $configurePresets.Contains($configureCandidate)) {
        return $configureCandidate
      }
      if ($workflowCandidate -ne $candidate -and $configurePresets.Contains($workflowCandidate)) {
        return $workflowCandidate
      }
    }
  }

  Write-Error "Could not resolve CMake preset '$Preset'."
  if ($script:USE_CMAKE_WORKFLOW) {
    Write-Error "Available workflow presets:"
    foreach ($name in $workflowPresets) {
      Write-Error "  $name"
    }
  } else {
    Write-Error "Available workflow presets:"
    Write-Error "  (workflow presets unavailable)"
    Write-Error "Available configure presets:"
    if ($configurePresets.Count -gt 0) {
      foreach ($name in $configurePresets) {
        Write-Error "  $name"
      }
    } else {
      Write-Error "  (none available or cmake --list-presets parsing failed)"
    }
  }
  throw "No compatible workflow preset found for '$Preset'"
}

function Resolve-CMakeWorkflowPreset {
  param([string] $Preset, [string] $SourceDir)
  $resolved = Resolve-CMakePreset -Preset $Preset -SourceDir $SourceDir
  return $resolved
}

function Resolve-TestBuildPreset {
  param([string] $Preset)

  $buildPreset = $Preset -replace '-notest', ''
  $buildPreset = $buildPreset -replace '-noexamples', ''
  $buildPreset = $buildPreset.Trim('-')
  return $buildPreset
}

foreach ($variant in $Variants) {
  $outputVariant = $variant
  if ($variant -eq "baseline") {
    $outputVariant = "avx2"
    Write-Host "[jhdf5] Variant 'baseline' is deprecated; building the AVX2 target as '$outputVariant'."
  }

	$env:POSTFIX = $outputVariant
	$requestedPreset = if ($env:CMAKE_PRESET) { $env:CMAKE_PRESET } else { "hict-StdShar-MSVC" }
  $requestedPreset = Normalize-CMakePreset -Preset $requestedPreset
  $sourceDir = Join-Path $PSScriptRoot "build\CMake-hdf5-1.10.11-$outputVariant\hdf5-1.10.11"
	$env:CMAKE_PRESET = Resolve-CMakeWorkflowPreset -Preset $requestedPreset -SourceDir $sourceDir
  switch ($variant) {
    "generic" { $env:CL = "/O2 /GL $initialCl" }
    "avx2" { $env:CL = "/O2 /arch:AVX2 /GL $initialCl" }
    "baseline" { $env:CL = "/O2 /arch:AVX2 /GL $initialCl" }
    "avx512" { $env:CL = "/O2 /arch:AVX512 /GL $initialCl" }
  }

  Write-Host "[jhdf5] Preparing Windows amd64 $outputVariant variant"
  bash (Join-Path $PSScriptRoot "prepare_winbuild.sh")

  if (-not (Test-Path $sourceDir)) {
    throw "Prepared HDF5 source directory was not found: $sourceDir"
  }

  Push-Location $sourceDir
  try {
    if ($script:USE_CMAKE_WORKFLOW) {
      Invoke-NativeTool "cmake" @("--workflow", "--preset", $env:CMAKE_PRESET, "--fresh")
    } else {
      Invoke-NativeTool "cmake" @("--preset", $env:CMAKE_PRESET, "--fresh")
      Invoke-NativeTool "cmake" @("--build", "--preset", (Resolve-TestBuildPreset -Preset $env:CMAKE_PRESET))
    }
  } finally {
    Pop-Location
  }

  $buildDirName = Resolve-TestBuildPreset -Preset $env:CMAKE_PRESET
  $binaryDir = Join-Path $sourceDir "build110\$buildDirName\bin\Release"
  $buildRoot = Join-Path $sourceDir "build110\$buildDirName"

  if ($RunTests) {
    Run-Hdf5TestSuite -BuildRoot $buildRoot -Variant $outputVariant
  }

  $deployDir = Join-Path $DeployRoot "amd64-Windows-$outputVariant"
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
  Write-Host "[jhdf5] Deployed Windows amd64 $outputVariant DLLs to $deployDir"
}

$genericDeployDir = Join-Path $DeployRoot "amd64-Windows"
$sourceGenericDir = Join-Path $DeployRoot "amd64-Windows-generic"
if (Test-Path $sourceGenericDir) {
  Remove-Item -Recurse -Force $genericDeployDir -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $genericDeployDir | Out-Null
  Copy-Item (Join-Path $sourceGenericDir "*") -Destination $genericDeployDir -Recurse -Force
  Write-Host "[jhdf5] Synced generic Windows payload to $genericDeployDir"
}
