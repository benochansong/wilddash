param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory = $true)]
    [string]$TimestampUrl,

    [string]$Description = "WILD DASH 3D",

    [switch]$MachineStore
)

$ErrorActionPreference = "Stop"

function Find-SignTool {
    $roots = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "$env:ProgramFiles\Windows Kits\10\bin"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $roots) {
        $candidate = Get-ChildItem -Path $root -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }

    $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    throw "SignTool.exe was not found. Install the Windows SDK/Visual Studio signing tools."
}

$resolved = (Resolve-Path $FilePath).Path
$thumbprint = ($CertificateThumbprint -replace '\s','').ToUpperInvariant()
$signtool = Find-SignTool

$args = @(
    "sign",
    "/sha1", $thumbprint,
    "/fd", "SHA256",
    "/tr", $TimestampUrl,
    "/td", "SHA256",
    "/d", $Description
)

if ($MachineStore) {
    $args += "/sm"
}

$args += $resolved

Write-Host "Signing $resolved with certificate thumbprint $thumbprint"
& $signtool @args
if ($LASTEXITCODE -ne 0) {
    throw "SignTool sign failed with exit code $LASTEXITCODE"
}

& "$PSScriptRoot\verify_windows_signature.ps1" -FilePath $resolved -RequireTimestamp
if ($LASTEXITCODE -ne 0) {
    throw "Post-signature verification failed with exit code $LASTEXITCODE"
}

Write-Host "WILDDASH CERT-STORE SIGN PASS file=$resolved"
