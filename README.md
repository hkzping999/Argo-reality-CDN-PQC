# Argo Reality CDN PQC MultiProfile v0.6.3

Experimental multi-profile VLESS deployment for Debian/Ubuntu VPS:

- Reality Vision Compat: VLESS + REALITY + Vision + `encryption=none`
- Reality Vision PQC: VLESS + REALITY + Vision + `mlkem768x25519plus` when supported
- VLESS WS Compat: Cloudflare Tunnel / CDN fallback + `encryption=none`
- VLESS WS PQC: Cloudflare Tunnel / CDN fallback + PQC when supported

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

or:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

## Fixed Cloudflare Tunnel

```bash
ARGO_TOKEN='your-cloudflared-token' \
ARGO_DOMAIN='proxy.example.com' \
REALITY_DOMAIN='reality.example.com' \
TLS_SERVER='www.microsoft.com' \
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

## Commands

```bash
argox-mp links
argox-mp status
argox-mp doctor
argox-mp logs
argox-mp restart
argox-mp uninstall
```

## First test order

1. Test `VLESS WS Compat` first.
2. Then test `Reality Vision Compat`.
3. Test PQC profiles only with clients that support Xray VLESS Encryption / `mlkem768x25519plus`.

If nodes do not connect, run:

```bash
argox-mp doctor
journalctl -u xray-argox-mp -u nginx-argox-mp -u cloudflared-argox-mp -n 120 --no-pager
```
