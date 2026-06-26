# Windows MSIX packaging

Wraps the v-sekai CockroachDB **Windows** build into a signed MSIX.

CockroachDB does not ship a supported Windows server build, but this fork
already cross/native-builds a Windows binary in
`.github/workflows/build-docker.yml` (`build-windows` job →
`make cockroachoss XGOOS=windows …`, uploaded as the `cockroach-windows-amd64`
artifact). The `msix` job in that workflow stages the binary as `cockroach.exe`
and runs `pack.ps1` to emit a signed `.msix`.

## Local use

From a Windows machine with the Windows SDK installed (provides
`makeappx.exe` / `signtool.exe`):

```powershell
# bin/ must contain cockroach.exe (+ optional libgeos*.dll)
pwsh packaging/msix/pack.ps1 -BinDir bin -Version 22.1.0.0
```

- Without `-PfxPath`, a **self-signed TEST cert** is generated; the resulting
  MSIX only installs after you trust that cert (import into
  *Local Machine → Trusted People*, then `Add-AppxPackage …`).
- With a real cert: `-PfxPath your.pfx -PfxPassword <pw>`. The cert subject
  **must** equal the manifest `Publisher` (default `CN=v-sekai`).

## Notes

- The console server is wrapped as a full-trust Win32 app (`runFullTrust`).
- Logo assets are generated as solid-colour placeholders at pack time if no
  PNGs are committed under `assets/`, keeping this packaging text-only.
- Windows is an **experimental** CockroachDB target; this is intended for
  local/dev use, not production. Linux (rpm/deb/container) remains primary.
