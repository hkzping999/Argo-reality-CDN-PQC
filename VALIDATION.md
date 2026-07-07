# Validation Report

Reference input: uploaded `Argo-reality-pqc-main.zip`.

## What was checked in the reference repo

- Main script: `argox.sh`, 4773 lines.
- Strong/PQC config: `config-pqc-strong.conf`.
- The reference script uses one global VLESS server/client encryption pair:
  - `VLESS_SERVER_DECRYPTION`
  - `VLESS_CLIENT_ENCRYPTION`
- Therefore all VLESS profiles share one encryption mode and cannot simultaneously expose `encryption=none` and `mlkem768x25519plus` as separate compatible/PQC nodes.

## What was changed in v0.6.1

- Rebuilt the deployer as a multi-profile system.
- Each profile has independent inbound/path/port and independent VLESS encryption mode.
- Default strict mode is disabled so compatible nodes still deploy even when the installed Xray does not support `xray vlessenc`.
- Added `--dry-run` to validate generated Xray JSON, Nginx config, and subscriptions without root/systemd.

## Local validation performed in the build environment

```bash
bash -n argox.sh
bash -n install.sh
bash argox.sh --dry-run
jq empty /tmp/argox-mp-dryrun/config.json
nginx -t -c /tmp/argox-mp-dryrun/nginx.conf

VLESS_PQC_DECRYPTION='mlkem768x25519plus.native.600s.fake' \
VLESS_PQC_ENCRYPTION='mlkem768x25519plus.native.1rtt.fake' \
ENABLE_XHTTP=y \
ARGO_DOMAIN='proxy.example.com' \
REALITY_DOMAIN='reality.example.com' \
bash argox.sh --dry-run
```

Results:

```text
default_inbounds=2
pqc_xhttp_inbounds=6
```

The environment was not a real Debian systemd VPS, so full service startup was not executed here. The generated package is designed for Debian 12 / Ubuntu 22.04+ root deployment.
