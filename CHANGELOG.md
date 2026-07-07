# Changelog

## v0.6.3-hotfix-connectivity

- Fix process-substitution installs: the installer no longer depends on copying `$0` when launched as `bash <(curl ...)` or `bash <(wget ...)`.
- Add fallback shortcut behavior: `argox-mp` can run the saved local script or fetch the configured upstream raw script.
- Add non-empty REALITY short ID generation and include it in Xray `shortIds` and client `sid=` links for better GUI client compatibility.
- Add `spx=%2F` to Reality share links.
- Add `argox-mp doctor` diagnostics for service state, listening ports, local Nginx, Cloudflare Tunnel reachability, and recent logs.
- Keep v0.6.2 binary replacement fix for `Text file busy`.
