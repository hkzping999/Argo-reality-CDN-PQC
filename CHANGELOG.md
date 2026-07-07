# Changelog

## 0.6.1-multiprofile-runnable

- Rebuilt from the uploaded `Argo-reality-pqc` reference as a cleaner runnable multi-profile package.
- Added separate compat/PQC inbounds instead of using one global VLESS encryption setting.
- Added Quick Tunnel and fixed Cloudflare Tunnel deployment paths.
- Added systemd units for Xray, local Nginx gateway, and cloudflared.
- Added subscription split: all, compat, pqc, reality, cdn, mihomo.
- Added `--dry-run` validation mode.
- Default `VLESS_PQC_STRICT=n` so the system still runs if Xray lacks `vlessenc`; set `VLESS_PQC_STRICT=y` for strict experiments.
