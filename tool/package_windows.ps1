[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Version,

  [Parameter(Mandatory)]
  [string]$GuiInputDirectory,

  [Parameter(Mandatory)]
  [string]$CliExecutable,

  [Parameter(Mandatory)]
  [string]$OutputDirectory,

  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw 'Version must use major.minor.patch.'
}
if (-not (Test-Path -LiteralPath $GuiInputDirectory -PathType Container)) {
  throw "GUI input directory does not exist: $GuiInputDirectory"
}
if (-not (Test-Path -LiteralPath $CliExecutable -PathType Leaf)) {
  throw "CLI executable does not exist: $CliExecutable"
}

$guiPortable = "chimera-gui-windows-x64-$Version-portable.zip"
$guiInstaller = "chimera-gui-windows-x64-$Version-installer.exe"
$cliPortable = "chimera-cli-windows-x64-$Version-portable.zip"
$cliInstaller = "chimera-cli-windows-x64-$Version-installer.exe"
$artifactNames = @($guiPortable, $guiInstaller, $cliPortable, $cliInstaller)

if ($DryRun) {
  $artifactNames | ForEach-Object { Write-Output $_ }
  return
}

$resolvedGui = (Resolve-Path -LiteralPath $GuiInputDirectory).Path
$resolvedCli = (Resolve-Path -LiteralPath $CliExecutable).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path

Compress-Archive -Path (Join-Path $resolvedGui '*') -DestinationPath (Join-Path $resolvedOutput $guiPortable) -CompressionLevel Optimal -Force
Compress-Archive -Path $resolvedCli -DestinationPath (Join-Path $resolvedOutput $cliPortable) -CompressionLevel Optimal -Force

$iscc = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
if ($null -eq $iscc) {
  $iscc = Get-Command 'iscc' -ErrorAction SilentlyContinue
}
if ($null -eq $iscc) {
  throw 'Inno Setup compiler (iscc) is required to create installer artifacts.'
}

& $iscc.Source "/DAppVersion=$Version" "/DSourceDirectory=$resolvedGui" "/DOutputDirectory=$resolvedOutput" "/DOutputBaseName=$([IO.Path]::GetFileNameWithoutExtension($guiInstaller))" 'deploy/windows/chimera_gui.iss'
if ($LASTEXITCODE -ne 0) {
  throw 'GUI installer creation failed.'
}

& $iscc.Source "/DAppVersion=$Version" "/DSourceExecutable=$resolvedCli" "/DOutputDirectory=$resolvedOutput" "/DOutputBaseName=$([IO.Path]::GetFileNameWithoutExtension($cliInstaller))" 'deploy/windows/chimera_cli.iss'
if ($LASTEXITCODE -ne 0) {
  throw 'CLI installer creation failed.'
}

$artifactNames | ForEach-Object {
  $artifactPath = Join-Path $resolvedOutput $_
  if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
    throw "Expected artifact was not created: $artifactPath"
  }
  Write-Output $artifactPath
}
