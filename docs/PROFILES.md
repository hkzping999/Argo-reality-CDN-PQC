# Profile Design

## Reality direct

Reality Vision 兼容版与 PQC 版必须拆成两个 inbound，因为 Xray VLESS inbound 的 `decryption` 是 inbound 级字段，不能同时兼容 `none` 和 `mlkem768x25519plus`。

```text
443  -> reality-vision-compat -> decryption=none
8443 -> reality-vision-pqc    -> decryption=mlkem768x25519plus...
```

## CDN / Tunnel

WS/XHTTP 也同理拆分路径：

```text
/argox-vl-c -> ws compat
/argox-vl-p -> ws pqc
/argox-xh-c -> xhttp compat
/argox-xh-p -> xhttp pqc
```

Quick Tunnel 默认禁用 XHTTP。固定 Cloudflare Tunnel 可设置 `ENABLE_XHTTP=y`。
