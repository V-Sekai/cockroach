<#
  Build + sign the CockroachDB MSIX from an already-built Windows binary.
  Requires Windows + Windows SDK (makeappx.exe, signtool.exe).

  The v-sekai fork produces a Windows binary via build-docker.yml's
  `build-windows` job (`make cockroachoss XGOOS=windows ...`, uploaded as the
  `cockroach-windows-amd64` artifact). Stage that exe (renamed cockroach.exe),
  plus any libgeos DLLs, into -BinDir and run this script.

  -BinDir   folder with cockroach.exe (+ optional libgeos*.dll)
  -Version  4-part version, e.g. 22.1.0.0
  -OutDir   output dir (default dist)
  -Publisher Identity Publisher; MUST equal the signing cert subject (default CN=v-sekai)
  -PfxPath  signing .pfx; if omitted a self-signed TEST cert is generated (test-install only)
  -PfxPassword  .pfx password, if any

  ex: pwsh packaging/msix/pack.ps1 -BinDir bin -Version 22.1.0.0
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$BinDir,
  [string]$Version  = "22.1.0.0",
  [string]$OutDir   = "dist",
  [string]$Publisher = "CN=v-sekai",
  [string]$PfxPath,
  [string]$PfxPassword
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path "$BinDir\cockroach.exe")) {
  throw "cockroach.exe not found in '$BinDir'. Stage the Windows build there first."
}

$sdk = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Directory |
       Where-Object { Test-Path "$($_.FullName)\x64\makeappx.exe" } |
       Sort-Object Name -Descending | Select-Object -First 1
if (-not $sdk) { throw "Windows SDK with makeappx.exe not found." }
$makeappx = "$($sdk.FullName)\x64\makeappx.exe"
$signtool = "$($sdk.FullName)\x64\signtool.exe"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("cockroach-msix-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path "$root\bin","$root\assets" | Out-Null
Copy-Item "$BinDir\*" "$root\bin\" -Recurse

# Visual assets: use committed PNGs if present, otherwise generate solid-colour
# placeholders so the package is self-contained without binary blobs in git.
$assetSrc = Join-Path $here "assets"
$logos = @{ "Square44x44Logo.png" = 44; "Square150x150Logo.png" = 150; "StoreLogo.png" = 50 }
foreach ($name in $logos.Keys) {
  $src = Join-Path $assetSrc $name
  $dst = Join-Path "$root\assets" $name
  if (Test-Path $src) { Copy-Item $src $dst; continue }
  $size = $logos[$name]
  try {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 105, 51, 255))  # cockroach-ish purple
    $g.Dispose()
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
  } catch {
    # Fallback: minimal 1x1 PNG if GDI+ is unavailable.
    $png1x1 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNgQAcAAA0AAekHHr0AAAAASUVORK5CYII="
    [IO.File]::WriteAllBytes($dst, [Convert]::FromBase64String($png1x1))
  }
}

[xml]$m = Get-Content "$here\AppxManifest.xml"
$m.Package.Identity.Version   = $Version
$m.Package.Identity.Publisher = $Publisher
$m.Save("$root\AppxManifest.xml")

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$msix = Join-Path $OutDir "v-sekai-cockroach-$Version.msix"
& $makeappx pack /o /d $root /p $msix
if ($LASTEXITCODE) { throw "makeappx failed ($LASTEXITCODE)" }

if (-not $PfxPath) {
  $cert = New-SelfSignedCertificate -Type Custom -Subject $Publisher `
            -KeyUsage DigitalSignature -CertStoreLocation "Cert:\CurrentUser\My" `
            -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3","2.5.29.19={text}")
  $PfxPath = Join-Path $OutDir "cockroach-test.pfx"; $PfxPassword = "test"
  Export-PfxCertificate -Cert $cert -FilePath $PfxPath `
    -Password (ConvertTo-SecureString $PfxPassword -AsPlainText -Force) | Out-Null
}
$pwArgs = if ($PfxPassword) { @("/p", $PfxPassword) } else { @() }
& $signtool sign /fd SHA256 /a /f $PfxPath @pwArgs $msix
if ($LASTEXITCODE) { throw "signtool failed ($LASTEXITCODE)" }

Write-Host "OK -> $msix"
