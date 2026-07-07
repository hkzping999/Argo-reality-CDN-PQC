# Changelog

## v0.7.0-running-base-multiprofile

- 改回已跑通原项目的服务骨架：`/etc/argox`、`xray.service`、`argo.service`。
- Nginx 由 Xray 服务 `ExecStartPre` 启动，不再拆独立 systemd 服务。
- cloudflared quick tunnel 使用原项目同类逻辑：`--url http://localhost:${NGINX_PORT}`。
- 保留多 profile 输出：Reality/WS 兼容版 + 可选 PQC 版。
- 增加 `argox doctor` 诊断。
- 安装/升级前停止旧服务，避免 Text file busy。
