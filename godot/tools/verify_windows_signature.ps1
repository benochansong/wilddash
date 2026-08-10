param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [switch]$RequireTimestamp
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
$sig = Get-AuthenticodeSignature -FilePath $resolved

if ($sig.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "Authenticode signature is not trusted/valid. Status=$($sig.Status) Message=$($sig.StatusMessage)"
}

if ($null -eq $sig.SignerCertificate) {
    throw "No signer certificate was returned for $resolved"
}

# Smart App Control currently requires an RSA-based trusted signature.
$rsaOid = "1.2.840.113549.1.1.1"
if ($sig.SignerCertificate.PublicKey.Oid.Value -ne $rsaOid) {
    throw "Signer certificate is not RSA. OID=$($sig.SignerCertificate.PublicKey.Oid.Value)"
}

if ($RequireTimestamp -and $null -eq $sig.TimeStamperCertificate) {
    throw "A trusted RFC3161 timestamp is required, but no timestamp certificate was found."
}

$signtool = Find-SignTool
& $signtool verify /pa /all /v /tw $resolved
if ($LASTEXITCODE -ne 0) {
    throw "SignTool verification failed with exit code $LASTEXITCODE"
}

$timestampSubject = if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { "none" }
Write-Host "WILDDASH SIGNATURE PASS"
Write-Host "  file=$resolved"
Write-Host "  subject=$($sig.SignerCertificate.Subject)"
Write-Host "  issuer=$($sig.SignerCertificate.Issuer)"
Write-Host "  thumbprint=$($sig.SignerCertificate.Thumbprint)"
Write-Host "  algorithm=RSA"
Write-Host "  timestamp=$timestampSubject"
