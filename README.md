# Argo Reality CDN PQC v0.7.0

## 设计原则

- 使用 `/etc/argox` 作为工作目录。
- 使用 `xray.service` 和 `argo.service` 两个 systemd 服务。
- Nginx 不单独拆成服务，由 `xray.service` 的 `ExecStartPre` 启动或重载。
- cloudflared quick tunnel 继续使用 `--url http://localhost:${NGINX_PORT}`。
- 默认生成兼容节点；PQC 仅在 Xray 支持 `vlessenc` 时输出。

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

或者：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

固定 Cloudflare Tunnel：

```bash
ARGO_TOKEN='你的 token' \
ARGO_DOMAIN='proxy.example.com' \
REALITY_DOMAIN='reality.example.com' \
TLS_SERVER='www.microsoft.com' \
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

## 管理命令

```bash
argox -n
argox status
argox doctor
argox restart
argox -u
```

## 默认节点

- Reality Vision Compat: `VLESS + Reality + Vision + encryption=none`
- VLESS WS Compat: `VLESS + WS + cloudflared + encryption=none`
- Reality Vision PQC: 仅在 `xray vlessenc` 可用时输出
- VLESS WS PQC: 仅在 `xray vlessenc` 可用时输出

## 重要说明

Reality 直连端口默认优先使用 TCP 443；如果端口已被占用，脚本会自动改用可用端口。Vultr Cloud Firewall 或其他云安全组需要手动放行对应 Reality 端口。WS/CDN 节点通过 cloudflared 隧道，不需要入站放行 8080。
