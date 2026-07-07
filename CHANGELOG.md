# Changelog

## v0.7.1-stable-first-pqc-1rtt

- 基于 v0.7.0 跑通项目骨架继续修复。
- 默认只启用兼容节点：Reality Vision Compat + VLESS WS Compat。
- PQC 节点默认不输出，避免主流客户端因超长 `mlkem768x25519plus` 链接无法导入/连接。
- 如需实验 PQC，部署时显式传入：
  `ENABLE_VLESS_PQC=y ENABLE_REALITY_PQC=y ENABLE_WS_PQC=y`。
- 继承原项目强模式关键逻辑：禁用 0-RTT，把服务端 decryption 第三段规范化为 `600s`，客户端 encryption 第三段规范化为 `1rtt`。
- 保留 `/etc/argox + xray.service + argo.service + Nginx ExecStartPre` 运行骨架。
