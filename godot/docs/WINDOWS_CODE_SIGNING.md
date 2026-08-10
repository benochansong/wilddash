# WILD DASH Windows Code Signing

This document defines the Windows signing policy for WILD DASH RC4 and later releases.

## Why this exists

Windows Smart App Control can block unknown unsigned executables. Public WILD DASH Windows builds should therefore use a trusted RSA Authenticode signature. A self-signed certificate is useful for local development only and is not a public-distribution solution.

The release pipeline must never publish a build as "signed" unless all of these gates pass:

1. Godot Windows export succeeds.
2. Unsigned executable smoke launch succeeds.
3. Trusted RSA Authenticode signing succeeds.
4. RFC3161 timestamp is present.
5. `Get-AuthenticodeSignature` reports `Valid`.
6. `SignTool verify /pa /all /v /tw` succeeds.
7. The signed executable is smoke-launched again and exits with code 0.
8. Only then is the signed ZIP eligible for a GitHub pre-release.

## Supported signing routes

### Route A — Microsoft Artifact Signing

Use this when the publisher is eligible for Microsoft Artifact Signing Public Trust.

Current Microsoft eligibility for Public Trust is geographically limited. Organizations are currently supported in the USA, Canada, European Union and United Kingdom. Individual developers are currently supported in the USA and Canada. Check Microsoft documentation before purchasing because availability can change.

Microsoft lists Artifact Signing Basic at about USD 9.99/month with 5,000 signatures/month. Do not create or purchase the service until the project owner explicitly approves the cost.

GitHub Actions configuration used by WILD DASH:

- `azure/login@v3`
- GitHub OIDC (`id-token: write`)
- `azure/artifact-signing-action@v2`
- SHA256 file digest
- RFC3161 SHA256 timestamp
- RSA public-trust certificate profile

Required GitHub Secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Required GitHub Variables:

- `WILDDASH_ARTIFACT_SIGNING_ENDPOINT`
- `WILDDASH_ARTIFACT_SIGNING_ACCOUNT`
- `WILDDASH_ARTIFACT_SIGNING_PROFILE`

The Microsoft Entra identity used by GitHub OIDC must have the Artifact Signing Certificate Profile Signer role on the signing profile.

### Route B — Trusted CA certificate + self-hosted Windows signing runner

Use this route when Microsoft Artifact Signing Public Trust is unavailable to the publisher.

Obtain a trusted RSA code-signing certificate from a public CA recognized by Windows. Microsoft documentation lists examples such as DigiCert, Sectigo, GlobalSign and SSL.com. Current public code-signing certificates commonly keep the private key in hardware or a managed signing service.

For a hardware-token certificate, the recommended WILD DASH automation pattern is:

1. Build on a GitHub-hosted Windows runner.
2. Upload only the unsigned EXE as a short-lived Actions artifact.
3. Run the signing job on a dedicated self-hosted Windows machine labelled `wilddash-signing`.
4. Keep the certificate/private key in the Windows certificate store / hardware token. Never commit it to GitHub.
5. Sign with `SignTool` using SHA256 and an RFC3161 timestamp.
6. Verify the signature with `godot/tools/verify_windows_signature.ps1`.
7. Smoke-launch the signed EXE.
8. Upload the signed artifact and publish only after all gates pass.

Required GitHub Secret:

- `WILDDASH_CERT_THUMBPRINT`

Required GitHub Variable:

- `WILDDASH_TIMESTAMP_URL`

The self-hosted machine must have:

- Windows 10/11
- Windows SDK / SignTool
- the CA certificate/token middleware
- the signing certificate visible in the Windows certificate store
- a GitHub Actions self-hosted runner with labels `self-hosted`, `windows`, `wilddash-signing`

Token PIN/unlock behavior is vendor-specific. Some hardware tokens require interactive unlock and therefore may not be suitable for unattended GitHub Actions without the CA's supported automation mechanism.

## Do not use these for public release

- no signature
- a locally generated self-signed certificate
- an ECC-only signing certificate for Smart App Control
- a PFX/private key committed to the repository
- a PFX/private key printed or reconstructed in workflow logs
- an unsigned EXE placed into a ZIP and described as signed

## RC3 policy

The already-published `v0.9.0-rc3` release remains an unsigned test build. Do not rewrite its history or claim that it is signed.

If RC3 must be redistributed externally, create a separate signed rebuild after a trusted signing identity is available and clearly label it as a signed rebuild rather than silently replacing the original binary.

## RC4 release policy

RC4 should use `.github/workflows/windows-signed-release-template.yml` as the release base.

Recommended flow:

`Gameplay CI -> Windows export -> unsigned smoke -> trusted signing -> signature verification -> signed smoke -> signed ZIP -> SHA256 -> GitHub pre-release`

`unsigned-test` mode is allowed only for internal testing and does not publish a GitHub release through the signed-release workflow.

For public RC4 distribution, select either:

- `artifact-signing`, or
- `self-hosted-cert-store`

and enable `publish_release` only after the signing configuration is ready.

## Smart App Control vs SmartScreen

A trusted signature is the important requirement for Smart App Control when Microsoft's app intelligence does not recognize a new binary. SmartScreen is a related but different reputation system. Even a correctly signed new app can still show SmartScreen reputation warnings until reputation builds. Never promise that code signing instantly eliminates every Windows warning.

## Verification helpers

### Verify a signed executable

```powershell
.\godot\tools\verify_windows_signature.ps1 `
  -FilePath .\WILD_DASH_3D.exe `
  -RequireTimestamp
```

### Sign from a Windows certificate store / hardware token

```powershell
.\godot\tools\sign_windows_cert_store.ps1 `
  -FilePath .\WILD_DASH_3D.exe `
  -CertificateThumbprint "<THUMBPRINT>" `
  -TimestampUrl "<RFC3161_TIMESTAMP_URL>" `
  -Description "WILD DASH 3D"
```

The helper deliberately does not accept or store a certificate private key or PFX password.
