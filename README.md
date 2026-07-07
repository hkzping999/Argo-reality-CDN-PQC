# Argo Reality PQC MultiProfile v0.6.1

但把原来的“全局 VLESS PQC 开关”改成了真正的 **multi-profile**：兼容版和 PQC 版分别使用独立 inbound、独立端口或路径。

上传到 GitHub 仓库根目录后运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh) -l
```

或者：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh) -l
```

## Quick Tunnel 实验部署

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh) -l
```

这会启动 `cloudflared --url http://127.0.0.1:8080` 并生成 `trycloudflare.com` 临时域名。Quick Tunnel 适合实验，不建议当生产长期入口。

## 固定 Cloudflare Tunnel 部署

```bash
ARGO_TOKEN='你的 cloudflared tunnel token' \
ARGO_DOMAIN='proxy.example.com' \
REALITY_DOMAIN='reality.example.com' \
TLS_SERVER='www.microsoft.com' \
ENABLE_XHTTP=y \
bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/argox.sh) -l
```



## 注意

本项目用于协议实验与合法网络连通性研究。请遵守所在地法律法规和服务条款。
