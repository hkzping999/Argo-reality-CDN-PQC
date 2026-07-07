# Argo Reality CDN PQC v0.7.1

这是稳定优先版：默认只输出兼容节点，先确保跑通。PQC 节点改为显式实验开关。

## 默认安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

默认输出：

- Reality Vision Compat：VLESS + Reality + Vision + encryption=none
- VLESS WS Compat：VLESS + WS + Argo/trycloudflare + encryption=none

## 实验 PQC 安装

```bash
ENABLE_VLESS_PQC=y ENABLE_REALITY_PQC=y ENABLE_WS_PQC=y \
VLESS_PQC_DISABLE_0RTT=y VLESS_PQC_CLIENT_RTT=1rtt VLESS_PQC_RESUME=600s \
bash <(curl -fsSL https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh)
```

PQC 节点只建议最新版 Xray-core / mihomo 测试；iOS 和普通 GUI 客户端优先使用 compat.txt。

## 管理

```bash
argox -n
argox doctor
argox -u
```
