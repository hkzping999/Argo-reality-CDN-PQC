#!/usr/bin/env bash
# Argo Reality CDN PQC - v0.7.0
# Running-base edition: keep the proven /etc/argox + xray.service + argo.service layout,
# add multi-profile VLESS Reality/WS with compat and optional PQC profiles.

set -Eeuo pipefail
umask 077

VERSION='0.7.0-running-base-multiprofile'
PROJECT_NAME='Argo Reality CDN PQC'
WORK_DIR=${WORK_DIR:-/etc/argox}
TEMP_DIR=${TEMP_DIR:-/tmp/argox-v070}
SUB_DIR="$WORK_DIR/subscribe"
CUSTOM_FILE="$WORK_DIR/custom"
XRAY_BIN="$WORK_DIR/xray"
CF_BIN="$WORK_DIR/cloudflared"
INBOUND_JSON="$WORK_DIR/inbound.json"
OUTBOUND_JSON="$WORK_DIR/outbound.json"
NGINX_CONF="$WORK_DIR/nginx.conf"
ARGO_SERVICE=/etc/systemd/system/argo.service
XRAY_SERVICE=/etc/systemd/system/xray.service
SHORTCUT=/usr/local/bin/argox
UPSTREAM_RAW_URL=${UPSTREAM_RAW_URL:-'https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh'}

NODE_NAME=${NODE_NAME:-Argo-PQC}
UUID=${UUID:-}
WS_PATH=${WS_PATH:-argox}
SUB_TOKEN=${SUB_TOKEN:-}
SERVER_IP=${SERVER_IP:-}
SERVER=${SERVER:-}
SERVER_PORT=${SERVER_PORT:-443}
TLS_SERVER=${TLS_SERVER:-addons.mozilla.org}
REALITY_DOMAIN=${REALITY_DOMAIN:-}
REALITY_PRIVATE=${REALITY_PRIVATE:-}
REALITY_PUBLIC=${REALITY_PUBLIC:-}
REALITY_SHORT_ID=${REALITY_SHORT_ID:-}

# Keep direct ports explicit. 443 is preferred for compat Reality; if occupied, installer will select a free port.
REALITY_COMPAT_PORT=${REALITY_COMPAT_PORT:-443}
REALITY_PQC_PORT=${REALITY_PQC_PORT:-8443}
VLESS_WS_COMPAT_PORT=${VLESS_WS_COMPAT_PORT:-30010}
VLESS_WS_PQC_PORT=${VLESS_WS_PQC_PORT:-30011}
VLESS_XHTTP_COMPAT_PORT=${VLESS_XHTTP_COMPAT_PORT:-30012}
VLESS_XHTTP_PQC_PORT=${VLESS_XHTTP_PQC_PORT:-30013}
NGINX_PORT=${NGINX_PORT:-8080}

ENABLE_REALITY_COMPAT=${ENABLE_REALITY_COMPAT:-y}
ENABLE_REALITY_PQC=${ENABLE_REALITY_PQC:-y}
ENABLE_WS_COMPAT=${ENABLE_WS_COMPAT:-y}
ENABLE_WS_PQC=${ENABLE_WS_PQC:-y}
ENABLE_XHTTP=${ENABLE_XHTTP:-auto} # auto only enables XHTTP for fixed ARGO_DOMAIN
ENABLE_VLESS_PQC=${ENABLE_VLESS_PQC:-y}
VLESS_PQC_STRICT=${VLESS_PQC_STRICT:-n}
VLESS_PQC_REQUIRE_PREFIX=${VLESS_PQC_REQUIRE_PREFIX:-mlkem768x25519plus}
VLESS_PQC_DECRYPTION=${VLESS_PQC_DECRYPTION:-}
VLESS_PQC_ENCRYPTION=${VLESS_PQC_ENCRYPTION:-}
PQC_READY=${PQC_READY:-n}

ARGO_DOMAIN=${ARGO_DOMAIN:-}
ARGO_TOKEN=${ARGO_TOKEN:-${ARGO_AUTH:-}}
ARGO_JSON=${ARGO_JSON:-}
ARGO_EDGE_IP_VERSION=${ARGO_EDGE_IP_VERSION:-auto}
AUTO_OPEN_FIREWALL=${AUTO_OPEN_FIREWALL:-y}
DRY_RUN=${DRY_RUN:-n}

red(){ printf '\033[31;1m%s\033[0m\n' "$*" >&2; }
green(){ printf '\033[32;1m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33;1m%s\033[0m\n' "$*"; }
info(){ printf '[INFO] %s\n' "$*"; }
warn(){ yellow "[WARN] $*"; }
fatal(){ red "[ERR] $*"; exit 1; }
truthy(){ case "${1:-}" in y|Y|yes|YES|true|TRUE|1|on|ON) return 0;; *) return 1;; esac; }
have(){ command -v "$1" >/dev/null 2>&1; }
need_root(){ truthy "$DRY_RUN" && return 0; [ "$(id -u)" -eq 0 ] || fatal '请以 root 运行：sudo -i 后再执行。'; }

cleanup(){ rm -rf "$TEMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT

mkdirs(){ mkdir -p "$WORK_DIR" "$TEMP_DIR" "$SUB_DIR"; chmod 700 "$WORK_DIR" "$TEMP_DIR"; chmod 755 "$SUB_DIR" 2>/dev/null || true; }

load_custom(){
  [ -s "$CUSTOM_FILE" ] || return 0
  while IFS='=' read -r k v; do
    [ -n "$k" ] || continue
    case "$k" in
      nodeName) NODE_NAME="$v";; uuid) UUID="$v";; wsPath) WS_PATH="$v";; subToken) SUB_TOKEN="$v";;
      serverIp) SERVER_IP="$v";; cdn) SERVER="$v";; cdnPort) SERVER_PORT="$v";; argoDomain) ARGO_DOMAIN="$v";;
      tlsServer) TLS_SERVER="$v";; realityDomain) [ "$v" = '__REALITY_DOMAIN_UNSET__' ] && REALITY_DOMAIN='' || REALITY_DOMAIN="$v";;
      privateKey) REALITY_PRIVATE="$v";; publicKey) REALITY_PUBLIC="$v";; shortId) REALITY_SHORT_ID="$v";;
      realityCompatPort) REALITY_COMPAT_PORT="$v";; realityPqcPort) REALITY_PQC_PORT="$v";;
      vlessWsCompatPort) VLESS_WS_COMPAT_PORT="$v";; vlessWsPqcPort) VLESS_WS_PQC_PORT="$v";;
      vlessXhttpCompatPort) VLESS_XHTTP_COMPAT_PORT="$v";; vlessXhttpPqcPort) VLESS_XHTTP_PQC_PORT="$v";; nginxPort) NGINX_PORT="$v";;
      enableRealityCompat) ENABLE_REALITY_COMPAT="$v";; enableRealityPqc) ENABLE_REALITY_PQC="$v";; enableWsCompat) ENABLE_WS_COMPAT="$v";; enableWsPqc) ENABLE_WS_PQC="$v";; enableXhttp) ENABLE_XHTTP="$v";;
      enableVlessPqc) ENABLE_VLESS_PQC="$v";; vlessPqcStrict) VLESS_PQC_STRICT="$v";; vlessPqcDecryption) VLESS_PQC_DECRYPTION="$v";; vlessPqcEncryption) VLESS_PQC_ENCRYPTION="$v";; pqcReady) PQC_READY="$v";;
    esac
  done < "$CUSTOM_FILE"
}

write_custom(){
  mkdirs
  {
    printf 'version=%s\n' "$VERSION"
    printf 'nodeName=%s\n' "$NODE_NAME"
    printf 'uuid=%s\n' "$UUID"
    printf 'wsPath=%s\n' "$WS_PATH"
    printf 'subToken=%s\n' "$SUB_TOKEN"
    printf 'serverIp=%s\n' "$SERVER_IP"
    printf 'cdn=%s\n' "${SERVER:-}"
    printf 'cdnPort=%s\n' "$SERVER_PORT"
    printf 'argoDomain=%s\n' "${ARGO_DOMAIN:-}"
    printf 'tlsServer=%s\n' "$TLS_SERVER"
    if [ -n "$REALITY_DOMAIN" ]; then printf 'realityDomain=%s\n' "$REALITY_DOMAIN"; else printf 'realityDomain=__REALITY_DOMAIN_UNSET__\n'; fi
    printf 'privateKey=%s\n' "$REALITY_PRIVATE"
    printf 'publicKey=%s\n' "$REALITY_PUBLIC"
    printf 'shortId=%s\n' "$REALITY_SHORT_ID"
    printf 'realityCompatPort=%s\n' "$REALITY_COMPAT_PORT"
    printf 'realityPqcPort=%s\n' "$REALITY_PQC_PORT"
    printf 'vlessWsCompatPort=%s\n' "$VLESS_WS_COMPAT_PORT"
    printf 'vlessWsPqcPort=%s\n' "$VLESS_WS_PQC_PORT"
    printf 'vlessXhttpCompatPort=%s\n' "$VLESS_XHTTP_COMPAT_PORT"
    printf 'vlessXhttpPqcPort=%s\n' "$VLESS_XHTTP_PQC_PORT"
    printf 'nginxPort=%s\n' "$NGINX_PORT"
    printf 'enableRealityCompat=%s\n' "$ENABLE_REALITY_COMPAT"
    printf 'enableRealityPqc=%s\n' "$ENABLE_REALITY_PQC"
    printf 'enableWsCompat=%s\n' "$ENABLE_WS_COMPAT"
    printf 'enableWsPqc=%s\n' "$ENABLE_WS_PQC"
    printf 'enableXhttp=%s\n' "$ENABLE_XHTTP"
    printf 'enableVlessPqc=%s\n' "$ENABLE_VLESS_PQC"
    printf 'vlessPqcStrict=%s\n' "$VLESS_PQC_STRICT"
    printf 'vlessPqcDecryption=%s\n' "$VLESS_PQC_DECRYPTION"
    printf 'vlessPqcEncryption=%s\n' "$VLESS_PQC_ENCRYPTION"
    printf 'pqcReady=%s\n' "$PQC_READY"
  } > "$CUSTOM_FILE"
  chmod 600 "$CUSTOM_FILE" 2>/dev/null || true
}

random_hex(){ local n=$1; openssl rand -hex "$n" 2>/dev/null || tr -dc 'a-f0-9' </dev/urandom | head -c $((n*2)); }
random_uuid(){ if [ -r /proc/sys/kernel/random/uuid ]; then cat /proc/sys/kernel/random/uuid; elif have uuidgen; then uuidgen | tr 'A-Z' 'a-z'; elif have python3; then python3 - <<'PYUUID'
import uuid
print(uuid.uuid4())
PYUUID
else printf '%08x-%04x-%04x-%04x-%012x\n' "$RANDOM$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM$RANDOM$RANDOM"; fi; }
url_encode(){ if have jq; then jq -rn --arg v "$1" '$v|@uri'; else python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; fi; }
uri_host(){ local h="$1"; [[ "$h" == *:* && "$h" != \[*\] ]] && printf '[%s]' "$h" || printf '%s' "$h"; }
reality_addr(){ [ -n "$REALITY_DOMAIN" ] && printf '%s' "$REALITY_DOMAIN" || printf '%s' "$SERVER_IP"; }
san_ws_path(){ WS_PATH=$(printf '%s' "$WS_PATH" | sed 's#^/##; s#[^A-Za-z0-9._@-]#-#g'); [ -n "$WS_PATH" ] || WS_PATH=argox; }

pkg_install(){
  truthy "$DRY_RUN" && return 0
  local pkgs=(wget curl unzip jq ca-certificates openssl procps iproute2 lsof nginx)
  if have apt-get; then apt-get update -y && apt-get install -y "${pkgs[@]}";
  elif have dnf; then dnf install -y "${pkgs[@]}";
  elif have yum; then yum install -y "${pkgs[@]}";
  elif have apk; then apk add --no-cache bash "${pkgs[@]}";
  else fatal '不支持的包管理器，请使用 Debian/Ubuntu/CentOS/Alpine/Arch。'; fi
  systemctl disable --now nginx >/dev/null 2>&1 || true
}

arch_assets(){
  case "$(uname -m)" in
    x86_64|amd64) XRAY_ASSET='Xray-linux-64.zip'; CF_ASSET='cloudflared-linux-amd64';;
    aarch64|arm64) XRAY_ASSET='Xray-linux-arm64-v8a.zip'; CF_ASSET='cloudflared-linux-arm64';;
    armv7l|armv7*) XRAY_ASSET='Xray-linux-arm32-v7a.zip'; CF_ASSET='cloudflared-linux-arm';;
    s390x) XRAY_ASSET='Xray-linux-s390x.zip'; CF_ASSET='cloudflared-linux-s390x';;
    *) fatal "暂不支持架构：$(uname -m)";;
  esac
}
download(){ local url=$1 out=$2; curl -fL --retry 3 --connect-timeout 20 -o "$out" "$url" || wget -O "$out" "$url"; }
atomic_install(){ local src=$1 dst=$2; install -m 700 "$src" "${dst}.new"; mv -f "${dst}.new" "$dst"; chmod 700 "$dst"; }

stop_old(){
  truthy "$DRY_RUN" && return 0
  systemctl disable --now argo.service xray.service >/dev/null 2>&1 || true
  nginx -c "$NGINX_CONF" -s stop >/dev/null 2>&1 || true
  pkill -9 -f "$WORK_DIR/cloudflared" >/dev/null 2>&1 || true
  pkill -9 -f "$WORK_DIR/xray run" >/dev/null 2>&1 || true
}

install_bins(){
  truthy "$DRY_RUN" && return 0
  arch_assets; mkdirs
  local tx="$TEMP_DIR/xray.zip" tc="$TEMP_DIR/cloudflared"
  info "下载 Xray-core: $XRAY_ASSET"
  download "https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_ASSET}" "$tx"
  unzip -qo "$tx" -d "$TEMP_DIR/xray"
  [ -x "$TEMP_DIR/xray/xray" ] || chmod +x "$TEMP_DIR/xray/xray" 2>/dev/null || true
  [ -x "$TEMP_DIR/xray/xray" ] || fatal 'Xray 解压失败。'
  atomic_install "$TEMP_DIR/xray/xray" "$XRAY_BIN"
  [ -f "$TEMP_DIR/xray/geoip.dat" ] && install -m 600 "$TEMP_DIR/xray/geoip.dat" "$WORK_DIR/geoip.dat" || true
  [ -f "$TEMP_DIR/xray/geosite.dat" ] && install -m 600 "$TEMP_DIR/xray/geosite.dat" "$WORK_DIR/geosite.dat" || true
  info "下载 cloudflared: $CF_ASSET"
  download "https://github.com/cloudflare/cloudflared/releases/latest/download/${CF_ASSET}" "$tc"
  atomic_install "$tc" "$CF_BIN"
}

get_ip(){
  [ -n "$SERVER_IP" ] && return 0
  truthy "$DRY_RUN" && { SERVER_IP=203.0.113.10; return 0; }
  SERVER_IP=$(curl -fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true)
  [ -n "$SERVER_IP" ] || SERVER_IP=$(curl -fsSL --max-time 8 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]' || true)
  [ -n "$SERVER_IP" ] || SERVER_IP=$(hostname -I | awk '{print $1}')
  [ -n "$SERVER_IP" ] || fatal '无法获取服务器公网 IP，请用 SERVER_IP=... 指定。'
}
port_used(){ ss -lntup 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:|\\])$1$"; }
free_port(){ local p=$1 min=${2:-30000}; while port_used "$p"; do p=$((p+1)); [ "$p" -gt 65530 ] && p=$min; done; printf '%s' "$p"; }
normalize_ports(){ truthy "$DRY_RUN" && return 0; REALITY_COMPAT_PORT=$(free_port "$REALITY_COMPAT_PORT" 30000); REALITY_PQC_PORT=$(free_port "$REALITY_PQC_PORT" 30001); VLESS_WS_COMPAT_PORT=$(free_port "$VLESS_WS_COMPAT_PORT" 30010); VLESS_WS_PQC_PORT=$(free_port "$VLESS_WS_PQC_PORT" 30011); VLESS_XHTTP_COMPAT_PORT=$(free_port "$VLESS_XHTTP_COMPAT_PORT" 30012); VLESS_XHTTP_PQC_PORT=$(free_port "$VLESS_XHTTP_PQC_PORT" 30013); NGINX_PORT=$(free_port "$NGINX_PORT" 8080); }

gen_reality_keys(){
  [ -n "$REALITY_PRIVATE" ] && [ -n "$REALITY_PUBLIC" ] && return 0
  truthy "$DRY_RUN" && { REALITY_PRIVATE=DRYRUN_PRIVATE; REALITY_PUBLIC=DRYRUN_PUBLIC; return 0; }
  local out; out=$($XRAY_BIN x25519 2>/dev/null || true)
  REALITY_PRIVATE=$(printf '%s\n' "$out" | awk -F': ' '/Private/{print $2; exit}' | awk '{print $NF}')
  REALITY_PUBLIC=$(printf '%s\n' "$out" | awk -F': ' '/Public/{print $2; exit}' | awk '{print $NF}')
  [ -n "$REALITY_PRIVATE" ] && [ -n "$REALITY_PUBLIC" ] || fatal 'Reality 密钥生成失败。'
}

prepare_pqc(){
  PQC_READY=n
  truthy "$ENABLE_VLESS_PQC" || return 0
  if [ -z "$VLESS_PQC_DECRYPTION" ] || [ -z "$VLESS_PQC_ENCRYPTION" ]; then
    if [ -x "$XRAY_BIN" ]; then
      local out flat section
      out=$($XRAY_BIN vlessenc 2>/dev/null || true)
      section=$(printf '%s\n' "$out" | awk '/Authentication:[[:space:]]*ML-KEM-768/{flag=1; next} flag && /Authentication:/{flag=0} flag')
      [ -n "$section" ] || section="$out"
      flat=$(printf '%s' "$section" | tr -d '\r\n')
      VLESS_PQC_DECRYPTION=$(printf '%s\n' "$flat" | sed -n 's/.*"decryption"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
      VLESS_PQC_ENCRYPTION=$(printf '%s\n' "$flat" | sed -n 's/.*"encryption"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    fi
  fi
  if [[ "$VLESS_PQC_DECRYPTION" == ${VLESS_PQC_REQUIRE_PREFIX}.* && "$VLESS_PQC_ENCRYPTION" == ${VLESS_PQC_REQUIRE_PREFIX}.* ]]; then
    PQC_READY=y
  else
    VLESS_PQC_DECRYPTION=''; VLESS_PQC_ENCRYPTION=''
    truthy "$VLESS_PQC_STRICT" && fatal 'Xray vlessenc 不可用或不支持 mlkem768x25519plus。'
    warn 'PQC profile 未启用；兼容节点继续部署。'
  fi
}

xhttp_on(){ case "$ENABLE_XHTTP" in y|Y|yes|1|true) return 0;; auto|'') [ -n "$ARGO_DOMAIN" ] && [[ ! "$ARGO_DOMAIN" =~ trycloudflare\.com$ ]] && return 0 || return 1;; *) return 1;; esac; }

write_inbounds(){
  mkdirs
  local d="$TEMP_DIR/inbounds"; rm -rf "$d"; mkdir -p "$d"; local n=0
  add_reality(){ local tag=$1 port=$2 dec=$3; n=$((n+1)); jq -n --arg tag "$NODE_NAME $tag" --arg id "$UUID" --arg dec "$dec" --arg dest "$TLS_SERVER:443" --arg sni "$TLS_SERVER" --arg pk "$REALITY_PRIVATE" --arg sid "$REALITY_SHORT_ID" --argjson port "$port" '{tag:$tag,listen:"0.0.0.0",port:$port,protocol:"vless",settings:{clients:[{id:$id,flow:"xtls-rprx-vision"}],decryption:$dec},streamSettings:{network:"tcp",security:"reality",realitySettings:{show:false,dest:$dest,xver:0,serverNames:[$sni],privateKey:$pk,shortIds:[$sid]}},sniffing:{enabled:true,destOverride:["http","tls"]}}' > "$d/$n.json"; }
  add_ws(){ local tag=$1 port=$2 dec=$3 path=$4; n=$((n+1)); jq -n --arg tag "$NODE_NAME $tag" --arg id "$UUID" --arg dec "$dec" --arg path "$path" --argjson port "$port" '{tag:$tag,listen:"127.0.0.1",port:$port,protocol:"vless",settings:{clients:[{id:$id}],decryption:$dec},streamSettings:{network:"ws",security:"none",wsSettings:{path:$path}},sniffing:{enabled:true,destOverride:["http","tls"]}}' > "$d/$n.json"; }
  add_xhttp(){ local tag=$1 port=$2 dec=$3 path=$4; n=$((n+1)); jq -n --arg tag "$NODE_NAME $tag" --arg id "$UUID" --arg dec "$dec" --arg path "$path" --argjson port "$port" '{tag:$tag,listen:"127.0.0.1",port:$port,protocol:"vless",settings:{clients:[{id:$id}],decryption:$dec},streamSettings:{network:"xhttp",security:"none",xhttpSettings:{path:$path,mode:"auto"}},sniffing:{enabled:true,destOverride:["http","tls"]}}' > "$d/$n.json"; }
  truthy "$ENABLE_REALITY_COMPAT" && add_reality reality-vision-compat "$REALITY_COMPAT_PORT" none
  truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY" && add_reality reality-vision-pqc "$REALITY_PQC_PORT" "$VLESS_PQC_DECRYPTION"
  truthy "$ENABLE_WS_COMPAT" && add_ws vless-ws-compat "$VLESS_WS_COMPAT_PORT" none "/$WS_PATH-vl-c"
  truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY" && add_ws vless-ws-pqc "$VLESS_WS_PQC_PORT" "$VLESS_PQC_DECRYPTION" "/$WS_PATH-vl-p"
  if xhttp_on; then
    add_xhttp vless-xhttp-cdn-compat "$VLESS_XHTTP_COMPAT_PORT" none "/$WS_PATH-xh-c"
    truthy "$PQC_READY" && add_xhttp vless-xhttp-cdn-pqc "$VLESS_XHTTP_PQC_PORT" "$VLESS_PQC_DECRYPTION" "/$WS_PATH-xh-p"
  fi
  [ "$n" -gt 0 ] || fatal '没有任何启用的 profile。'
  jq -s '{log:{access:"/dev/null",error:"/dev/null",loglevel:"warning"},inbounds:.,routing:{domainStrategy:"AsIs",rules:[]}}' "$d"/*.json > "$INBOUND_JSON"
  cat > "$OUTBOUND_JSON" <<'EOF'
{
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF
  chmod 600 "$INBOUND_JSON" "$OUTBOUND_JSON" 2>/dev/null || true
  if [ -x "$XRAY_BIN" ] && ! truthy "$DRY_RUN"; then $XRAY_BIN run -test -c "$INBOUND_JSON" -c "$OUTBOUND_JSON"; fi
}

nginx_ws_loc(){ local path=$1 port=$2; cat <<EOF
    location ~ ^${path} {
      proxy_pass          http://127.0.0.1:${port};
      proxy_http_version  1.1;
      proxy_set_header    Upgrade \$http_upgrade;
      proxy_set_header    Connection "upgrade";
      proxy_set_header    X-Real-IP \$remote_addr;
      proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header    Host \$host;
      proxy_redirect      off;
      proxy_buffering     off;
      proxy_read_timeout  1h;
      proxy_send_timeout  1h;
    }
EOF
}
nginx_xhttp_loc(){ local path=$1 port=$2; cat <<EOF
    location ~ ^${path} {
      proxy_pass                  http://127.0.0.1:${port};
      proxy_http_version          1.1;
      proxy_set_header            Host \$host;
      proxy_set_header            X-Real-IP \$remote_addr;
      proxy_set_header            X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header            X-Forwarded-Proto \$scheme;
      proxy_redirect              off;
      proxy_buffering             off;
      proxy_request_buffering     off;
      proxy_max_temp_file_size    0;
      client_max_body_size        0;
      proxy_read_timeout          1h;
      proxy_send_timeout          1h;
    }
EOF
}
write_nginx(){
  local locs=''
  truthy "$ENABLE_WS_COMPAT" && locs+="$(nginx_ws_loc "/$WS_PATH-vl-c" "$VLESS_WS_COMPAT_PORT")"$'\n'
  truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY" && locs+="$(nginx_ws_loc "/$WS_PATH-vl-p" "$VLESS_WS_PQC_PORT")"$'\n'
  if xhttp_on; then
    locs+="$(nginx_xhttp_loc "/$WS_PATH-xh-c" "$VLESS_XHTTP_COMPAT_PORT")"$'\n'
    truthy "$PQC_READY" && locs+="$(nginx_xhttp_loc "/$WS_PATH-xh-p" "$VLESS_XHTTP_PQC_PORT")"$'\n'
  fi
  cat > "$NGINX_CONF" <<EOF
user root;
worker_processes auto;
error_log /dev/null;
pid /var/run/nginx.pid;
events { worker_connections 1024; }
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log off;
  sendfile on;
  keepalive_timeout 65;
  server {
    listen ${NGINX_PORT};
    server_name localhost;
    location = / { default_type text/plain; return 200 "${PROJECT_NAME} ${VERSION}\\n"; }
${locs}
    location ~ ^/${SUB_TOKEN}/(.+)$ {
      autoindex on;
      default_type text/plain;
      alias ${SUB_DIR}/\$1;
      add_header Cache-Control "no-store" always;
    }
  }
}
EOF
  nginx -t -c "$NGINX_CONF" >/dev/null
}

write_services(){
  if [ -n "$ARGO_TOKEN" ]; then
    ARGO_RUNS="$CF_BIN tunnel --edge-ip-version $ARGO_EDGE_IP_VERSION --no-autoupdate run --token $ARGO_TOKEN"
  else
    ARGO_RUNS="$CF_BIN tunnel --edge-ip-version $ARGO_EDGE_IP_VERSION --no-autoupdate --url http://localhost:${NGINX_PORT}"
  fi
  cat > "$ARGO_SERVICE" <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target xray.service
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=${ARGO_RUNS}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  cat > "$XRAY_SERVICE" <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target
Wants=network.target

[Service]
User=root
ExecStartPre=/bin/bash -c 'if [ -s ${NGINX_CONF} ]; then nginx -t -c ${NGINX_CONF} >/dev/null 2>&1 && (nginx -c ${NGINX_CONF} -s reload 2>/dev/null || nginx -c ${NGINX_CONF}); fi'
ExecStartPre=${XRAY_BIN} run -test -c ${INBOUND_JSON} -c ${OUTBOUND_JSON}
ExecStart=${XRAY_BIN} run -c ${INBOUND_JSON} -c ${OUTBOUND_JSON}
ExecStopPost=/bin/bash -c 'nginx -c ${NGINX_CONF} -s stop >/dev/null 2>&1 || true'
Restart=on-failure
RestartPreventExitStatus=23
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable argo.service xray.service >/dev/null
}

parse_argo_domain(){
  [ -n "$ARGO_DOMAIN" ] && return 0
  truthy "$DRY_RUN" && { ARGO_DOMAIN=example.trycloudflare.com; return 0; }
  local d=''
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    d=$(journalctl -u argo.service -n 200 --no-pager 2>/dev/null | grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' | tail -1 | sed 's#https://##' || true)
    [ -n "$d" ] && break
    sleep 2
  done
  [ -n "$d" ] && ARGO_DOMAIN="$d" || warn '暂未解析到 trycloudflare 域名；请稍后运行 argox -n。'
}

open_firewall(){
  truthy "$AUTO_OPEN_FIREWALL" || return 0
  truthy "$DRY_RUN" && return 0
  local ports=(); truthy "$ENABLE_REALITY_COMPAT" && ports+=("${REALITY_COMPAT_PORT}/tcp"); truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY" && ports+=("${REALITY_PQC_PORT}/tcp")
  if have ufw && ufw status 2>/dev/null | grep -qi active; then for p in "${ports[@]}"; do ufw allow "$p" >/dev/null 2>&1 || true; done; fi
  if have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then for p in "${ports[@]}"; do firewall-cmd --permanent --add-port="$p" >/dev/null 2>&1 || true; done; firewall-cmd --reload >/dev/null 2>&1 || true; fi
}

build_reality_uri(){ local label=$1 port=$2 enc=$3; local addr name; addr=$(uri_host "$(reality_addr)"); name=$(url_encode "$NODE_NAME $label"); printf 'vless://%s@%s:%s?encryption=%s&flow=xtls-rprx-vision&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&spx=%%2F&type=tcp&headerType=none#%s\n' "$UUID" "$addr" "$port" "$(url_encode "$enc")" "$(url_encode "$TLS_SERVER")" "$REALITY_PUBLIC" "$REALITY_SHORT_ID" "$name"; }
build_ws_uri(){ local label=$1 suffix=$2 enc=$3; [ -n "$ARGO_DOMAIN" ] || return 0; local name; name=$(url_encode "$NODE_NAME $label"); printf 'vless://%s@%s:443?encryption=%s&security=tls&sni=%s&fp=chrome&type=ws&host=%s&path=%s#%s\n' "$UUID" "$ARGO_DOMAIN" "$(url_encode "$enc")" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$(url_encode "/$WS_PATH-$suffix")" "$name"; }
build_xhttp_uri(){ local label=$1 suffix=$2 enc=$3; [ -n "$ARGO_DOMAIN" ] || return 0; local name; name=$(url_encode "$NODE_NAME $label"); printf 'vless://%s@%s:443?encryption=%s&security=tls&sni=%s&fp=chrome&type=xhttp&host=%s&path=%s&mode=auto#%s\n' "$UUID" "$ARGO_DOMAIN" "$(url_encode "$enc")" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$(url_encode "/$WS_PATH-$suffix")" "$name"; }

gen_subs(){
  mkdir -p "$SUB_DIR"
  : > "$SUB_DIR/compat.txt"; : > "$SUB_DIR/pqc.txt"; : > "$SUB_DIR/reality.txt"; : > "$SUB_DIR/cdn.txt"; : > "$SUB_DIR/all.txt"
  truthy "$ENABLE_REALITY_COMPAT" && build_reality_uri 'Reality Vision Compat' "$REALITY_COMPAT_PORT" none >> "$SUB_DIR/compat.txt"
  truthy "$ENABLE_WS_COMPAT" && build_ws_uri 'VLESS WS Compat' vl-c none >> "$SUB_DIR/compat.txt"
  truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY" && build_reality_uri 'Reality Vision PQC' "$REALITY_PQC_PORT" "$VLESS_PQC_ENCRYPTION" >> "$SUB_DIR/pqc.txt"
  truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY" && build_ws_uri 'VLESS WS PQC' vl-p "$VLESS_PQC_ENCRYPTION" >> "$SUB_DIR/pqc.txt"
  if xhttp_on; then
    build_xhttp_uri 'VLESS XHTTP CDN Compat' xh-c none >> "$SUB_DIR/compat.txt"
    truthy "$PQC_READY" && build_xhttp_uri 'VLESS XHTTP CDN PQC' xh-p "$VLESS_PQC_ENCRYPTION" >> "$SUB_DIR/pqc.txt"
  fi
  cat "$SUB_DIR/compat.txt" "$SUB_DIR/pqc.txt" > "$SUB_DIR/all.txt"
  grep 'Reality' "$SUB_DIR/all.txt" > "$SUB_DIR/reality.txt" || true
  grep -E 'WS|XHTTP' "$SUB_DIR/all.txt" > "$SUB_DIR/cdn.txt" || true
  cat > "$SUB_DIR/mihomo.yaml" <<EOF
proxies:
$(awk '{gsub(/"/,"\\\""); print "  # " $0}' "$SUB_DIR/all.txt")
EOF
  chmod -R a+rX "$SUB_DIR" 2>/dev/null || true
}

show_links(){
  parse_argo_domain || true; gen_subs; write_custom
  echo
  echo '--- compat.txt ---'; cat "$SUB_DIR/compat.txt" || true
  echo; echo '--- pqc.txt ---'; cat "$SUB_DIR/pqc.txt" || true
  if [ -n "$ARGO_DOMAIN" ]; then
    echo; echo '--- remote subscriptions ---'
    echo "https://${ARGO_DOMAIN}/${SUB_TOKEN}/compat.txt"
    echo "https://${ARGO_DOMAIN}/${SUB_TOKEN}/pqc.txt"
    echo "https://${ARGO_DOMAIN}/${SUB_TOKEN}/all.txt"
  fi
}

write_shortcut(){
  cat > "$SHORTCUT" <<EOF
#!/usr/bin/env bash
if [ -s ${WORK_DIR}/argox.sh ]; then exec bash ${WORK_DIR}/argox.sh "\$@"; fi
exec bash <(curl -fsSL ${UPSTREAM_RAW_URL}) "\$@"
EOF
  chmod +x "$SHORTCUT"
  ln -sf "$SHORTCUT" /usr/local/bin/argox-mp 2>/dev/null || true
}
copy_self(){ local self=${BASH_SOURCE[0]}; if [ -f "$self" ]; then install -m 700 "$self" "$WORK_DIR/argox.sh"; else download "$UPSTREAM_RAW_URL" "$TEMP_DIR/argox.sh" >/dev/null 2>&1 && install -m 700 "$TEMP_DIR/argox.sh" "$WORK_DIR/argox.sh" || true; fi; }

install_all(){
  need_root; load_custom; mkdirs
  san_ws_path
  [ -n "$UUID" ] || UUID=$(random_uuid)
  [ -n "$SUB_TOKEN" ] || SUB_TOKEN=$(random_hex 12)
  [ -n "$REALITY_SHORT_ID" ] || REALITY_SHORT_ID=$(random_hex 8)
  get_ip
  pkg_install
  stop_old
  install_bins
  normalize_ports
  gen_reality_keys
  prepare_pqc
  write_inbounds
  write_nginx
  open_firewall
  write_custom
  copy_self
  write_shortcut
  write_services
  systemctl restart xray.service
  systemctl restart argo.service
  sleep 2
  parse_argo_domain || true
  gen_subs
  write_custom
  show_links
  green "安装完成。管理命令：argox -n | argox doctor | argox -u"
  warn "如果 Reality 直连不通，请检查 VPS 平台安全组是否放行 TCP ${REALITY_COMPAT_PORT}${PQC_READY:+/${REALITY_PQC_PORT}}。"
}

status(){ systemctl --no-pager --full status xray.service argo.service || true; }
doctor(){ load_custom; echo "${PROJECT_NAME} ${VERSION} doctor"; echo "WORK_DIR=$WORK_DIR"; echo "Reality=$(reality_addr):$REALITY_COMPAT_PORT sid=${REALITY_SHORT_ID:-}"; echo "Argo=${ARGO_DOMAIN:-not-ready}"; echo; systemctl is-active xray.service argo.service 2>/dev/null || true; echo; ss -lntup 2>/dev/null | grep -E ":(${REALITY_COMPAT_PORT}|${REALITY_PQC_PORT}|${NGINX_PORT}|${VLESS_WS_COMPAT_PORT}|${VLESS_WS_PQC_PORT})\b" || true; echo; curl -sS --max-time 5 "http://127.0.0.1:${NGINX_PORT}/" || true; echo; curl -sS -o /dev/null -w "local_ws_status=%{http_code}\n" --max-time 5 "http://127.0.0.1:${NGINX_PORT}/${WS_PATH}-vl-c" || true; echo; parse_argo_domain || true; [ -n "$ARGO_DOMAIN" ] && curl -k -sS -o /dev/null -w "public_root_status=%{http_code}\n" --max-time 12 "https://${ARGO_DOMAIN}/" || true; echo; journalctl -u xray.service -u argo.service -n 100 --no-pager || true; }
uninstall(){ need_root; systemctl disable --now argo.service xray.service >/dev/null 2>&1 || true; nginx -c "$NGINX_CONF" -s stop >/dev/null 2>&1 || true; rm -f "$ARGO_SERVICE" "$XRAY_SERVICE" "$SHORTCUT" /usr/local/bin/argox-mp; systemctl daemon-reload >/dev/null 2>&1 || true; rm -rf "$WORK_DIR"; green '已卸载。'; }
restart(){ need_root; load_custom; write_inbounds; write_nginx; gen_subs; write_custom; systemctl restart xray.service argo.service; show_links; }
dry_run(){ DRY_RUN=y; WORK_DIR=/tmp/argox-v070-dry; TEMP_DIR=/tmp/argox-v070-temp; SUB_DIR="$WORK_DIR/subscribe"; CUSTOM_FILE="$WORK_DIR/custom"; XRAY_BIN="$WORK_DIR/xray"; CF_BIN="$WORK_DIR/cloudflared"; INBOUND_JSON="$WORK_DIR/inbound.json"; OUTBOUND_JSON="$WORK_DIR/outbound.json"; NGINX_CONF="$WORK_DIR/nginx.conf"; rm -rf "$WORK_DIR" "$TEMP_DIR"; mkdirs; UUID=$(random_uuid); SUB_TOKEN=$(random_hex 12); SERVER_IP=203.0.113.10; REALITY_PRIVATE=DRYRUN_PRIVATE; REALITY_PUBLIC=DRYRUN_PUBLIC; REALITY_SHORT_ID=0123456789abcdef; PQC_READY=n; san_ws_path; write_inbounds; write_nginx || true; ARGO_DOMAIN=example.trycloudflare.com; gen_subs; jq empty "$INBOUND_JSON"; green "dry-run OK: $WORK_DIR"; find "$WORK_DIR" -maxdepth 2 -type f | sort; }
usage(){ cat <<EOF
${PROJECT_NAME} ${VERSION}
Usage:
  bash argox.sh          install / reinstall
  argox -n|links         show nodes
  argox status           service status
  argox doctor           connectivity diagnostics
  argox restart          regenerate config and restart
  argox -u|uninstall     uninstall
  bash argox.sh --dry-run
EOF
}

case "${1:-install}" in
  install|-l|--install) install_all;;
  -n|links|link) load_custom; show_links;;
  status|-s) status;;
  doctor|check) doctor;;
  restart|-r) restart;;
  -u|uninstall) uninstall;;
  --dry-run) dry_run;;
  -h|--help|help) usage;;
  *) usage; exit 1;;
esac
