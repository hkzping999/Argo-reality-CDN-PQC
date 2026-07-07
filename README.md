# Argo Reality PQC MultiProfile v0.6.1

这是基于 `hkzping999/Argo-reality-pqc` 架构重新整理的多版本实验系统。它保留原项目的核心路径：

```text
Cloudflare Tunnel / Argo -> Nginx local gateway -> Xray VLESS WS/XHTTP
Client direct -> Xray VLESS Reality Vision
```

但把原来的“全局 VLESS PQC 开关”改成了真正的 **multi-profile**：兼容版和 PQC 版分别使用独立 inbound、独立端口或路径。

## 默认 profile

| Profile | 协议 | 默认端口/路径 | 说明 |
|---|---|---:|---|
| Reality Vision Compat | VLESS + REALITY + Vision + `encryption=none` | `443` | 主流客户端优先 |
| Reality Vision PQC | VLESS + REALITY + Vision + `mlkem768x25519plus` | `8443` | Xray/mihomo 新版本优先 |
| WS Compat | VLESS + WS + Tunnel/CDN + `encryption=none` | `/argox-vl-c` | 通用备用 |
| WS PQC | VLESS + WS + Tunnel/CDN + PQC | `/argox-vl-p` | 支持 VLESS Encryption 的客户端 |
| XHTTP CDN Compat/PQC | VLESS + XHTTP + Tunnel/CDN | `/argox-xh-c`, `/argox-xh-p` | 固定 Tunnel 时启用 |

## 一键部署

上传到 GitHub 仓库根目录后运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/argox.sh) -l
```

或者：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/你的用户名/你的仓库/main/argox.sh) -l
```

## Quick Tunnel 实验部署

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/argox.sh) -l
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

说明：

- `ARGO_DOMAIN` 是 Cloudflare Tunnel/CDN 入口域名。
- `REALITY_DOMAIN` 是 Reality 客户端连接地址，留空则使用 VPS IP。
- `TLS_SERVER` 是 Reality 伪装 SNI / dest 域名。
- `ENABLE_XHTTP=auto` 时，只有固定 `ARGO_DOMAIN` 才会启用 XHTTP。

## 使用配置文件部署

```bash
cp config.example.conf config.conf
vim config.conf
bash argox.sh -f config.conf
```

## 管理命令

安装后会创建：

```bash
argox-mp status
argox-mp links
argox-mp restart
argox-mp logs
argox-mp uninstall
```

## 订阅文件

```text
/etc/argox-mp/subscribe/all.txt
/etc/argox-mp/subscribe/compat.txt
/etc/argox-mp/subscribe/pqc.txt
/etc/argox-mp/subscribe/reality.txt
/etc/argox-mp/subscribe/cdn.txt
/etc/argox-mp/subscribe/mihomo.yaml
```

远程订阅格式：

```text
https://ARGO_DOMAIN/sub/SUB_TOKEN/compat.txt
https://ARGO_DOMAIN/sub/SUB_TOKEN/pqc.txt
https://ARGO_DOMAIN/sub/SUB_TOKEN/all.txt
https://ARGO_DOMAIN/sub/SUB_TOKEN/mihomo.yaml
```

`SUB_TOKEN` 会在安装时随机生成并保存到 `/etc/argox-mp/custom.env`。

## 客户端建议

- Shadowrocket / Loon / Quantumult X / Egern / sing-box 系：优先使用 `compat.txt`。
- v2rayN + 最新 Xray-core：可测试 `pqc.txt`。
- mihomo / Clash Meta：优先使用 `mihomo.yaml`。
- 不确定客户端是否支持 `mlkem768x25519plus` 时，不要导入 PQC 节点。

## 与原库 2.2.3 的关键差异

原库的 2.2.3 逻辑是：

```text
所有 VLESS 入站共享 VLESS_SERVER_DECRYPTION
所有 VLESS 分享链接共享 VLESS_CLIENT_ENCRYPTION
```

这导致无法同时提供 `encryption=none` 的主流兼容节点和 `mlkem768x25519plus` 的高级节点。

v0.6.1 改为：

```text
reality-vision-compat -> decryption=none
reality-vision-pqc    -> decryption=mlkem768x25519plus...
ws-compat             -> decryption=none
ws-pqc                -> decryption=mlkem768x25519plus...
xhttp-compat          -> decryption=none
xhttp-pqc             -> decryption=mlkem768x25519plus...
```

这样可以保证“可用性”和“安全增强”同时存在。

## 本地语法/配置测试

```bash
bash -n argox.sh
bash argox.sh --dry-run
```

`--dry-run` 会在 `/tmp/argox-mp-dryrun` 生成 Xray/Nginx/订阅文件，不需要 root，也不会下载或启动服务。

## 注意

本项目用于协议实验与合法网络连通性研究。请遵守所在地法律法规和服务条款。
