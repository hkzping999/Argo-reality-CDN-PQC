#!/usr/bin/env bash
# Argo Reality PQC MultiProfile
# Based on the Argo-reality-pqc deployment model, rewritten as a multi-profile runnable installer.

set -Eeuo pipefail

VERSION='0.6.3-hotfix-connectivity'
PROJECT_NAME='Argo Reality PQC MultiProfile'

WORK_DIR=${WORK_DIR:-/etc/argox-mp}
BIN_DIR="$WORK_DIR/bin"
SUB_DIR="$WORK_DIR/subscribe"
LOG_DIR="$WORK_DIR/logs"
RUN_DIR="$WORK_DIR/run"
CUSTOM_FILE="$WORK_DIR/custom.env"
XRAY_BIN="$BIN_DIR/xray"
CLOUDFLARED_BIN="$BIN_DIR/cloudflared"
CONFIG_FILE="$WORK_DIR/config.json"
NGINX_CONF="$WORK_DIR/nginx.conf"
SERVICE_XRAY='xray-argox-mp.service'
SERVICE_NGINX='nginx-argox-mp.service'
SERVICE_CF='cloudflared-argox-mp.service'
UPSTREAM_RAW_URL=${UPSTREAM_RAW_URL:-'https://raw.githubusercontent.com/hkzping999/Argo-reality-CDN-PQC/main/argox.sh'}

# ---------- defaults ----------
NODE_NAME=${NODE_NAME:-'Argo-PQC-MP'}
UUID=${UUID:-''}
WS_PATH=${WS_PATH:-argox}
SUB_TOKEN=${SUB_TOKEN:-''}
SERVER_IP=${SERVER_IP:-''}
SERVER=${SERVER:-''}
SERVER_PORT=${SERVER_PORT:-443}

TLS_SERVER=${TLS_SERVER:-addons.mozilla.org}
REALITY_DOMAIN=${REALITY_DOMAIN:-''}
REALITY_PRIVATE=${REALITY_PRIVATE:-''}
REALITY_PUBLIC=${REALITY_PUBLIC:-''}
REALITY_SHORT_ID=${REALITY_SHORT_ID:-''}

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
# auto: enable only when a fixed ARGO_DOMAIN is supplied. Quick trycloudflare keeps XHTTP disabled by default.
ENABLE_XHTTP=${ENABLE_XHTTP:-auto}
ENABLE_VLESS_PQC=${ENABLE_VLESS_PQC:-y}
# n by default so the system remains deployable even when the installed Xray lacks vlessenc.
VLESS_PQC_STRICT=${VLESS_PQC_STRICT:-n}
VLESS_PQC_REQUIRE_PREFIX=${VLESS_PQC_REQUIRE_PREFIX:-mlkem768x25519plus}
VLESS_PQC_DISABLE_0RTT=${VLESS_PQC_DISABLE_0RTT:-y}
VLESS_PQC_RESUME=${VLESS_PQC_RESUME:-600s}
VLESS_PQC_CLIENT_RTT=${VLESS_PQC_CLIENT_RTT:-1rtt}
VLESS_PQC_DECRYPTION=${VLESS_PQC_DECRYPTION:-''}
VLESS_PQC_ENCRYPTION=${VLESS_PQC_ENCRYPTION:-''}
PQC_READY=${PQC_READY:-n}

ARGO_DOMAIN=${ARGO_DOMAIN:-''}
ARGO_TOKEN=${ARGO_TOKEN:-${ARGO_AUTH:-''}}
ARGO_EDGE_IP_VERSION=${ARGO_EDGE_IP_VERSION:-auto}
INSTALL_NGINX_PACKAGE=${INSTALL_NGINX_PACKAGE:-y}
AUTO_OPEN_FIREWALL=${AUTO_OPEN_FIREWALL:-y}

DRY_RUN=${DRY_RUN:-n}
NONINTERACTIVE=${NONINTERACTIVE:-y}

# ---------- ui ----------
red() { printf '\033[31;1m%s\033[0m\n' "$*" >&2; }
green() { printf '\033[32;1m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33;1m%s\033[0m\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { yellow "[WARN] $*"; }
fatal() { red "[ERR] $*"; exit 1; }

truthy() {
  case "${1:-}" in
    y|Y|yes|YES|true|TRUE|1|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

need_root() {
  truthy "$DRY_RUN" && return 0
  [ "$(id -u)" -eq 0 ] || fatal "请以 root 运行：sudo -i 后再执行。"
}

have() { command -v "$1" >/dev/null 2>&1; }

safe_mkdirs() {
  mkdir -p "$WORK_DIR" "$BIN_DIR" "$SUB_DIR" "$LOG_DIR" "$RUN_DIR"
  chmod 700 "$WORK_DIR" "$BIN_DIR" "$LOG_DIR" "$RUN_DIR" 2>/dev/null || true
  chmod 755 "$SUB_DIR" 2>/dev/null || true
}

load_custom() {
  [ -s "$CUSTOM_FILE" ] || return 0
  # shellcheck disable=SC1090
  . "$CUSTOM_FILE"
}

shell_quote() { printf "%q" "$1"; }

save_custom() {
  safe_mkdirs
  {
    printf 'VERSION=%q\n' "$VERSION"
    printf 'NODE_NAME=%q\n' "$NODE_NAME"
    printf 'UUID=%q\n' "$UUID"
    printf 'WS_PATH=%q\n' "$WS_PATH"
    printf 'SUB_TOKEN=%q\n' "$SUB_TOKEN"
    printf 'SERVER_IP=%q\n' "$SERVER_IP"
    printf 'SERVER=%q\n' "$SERVER"
    printf 'SERVER_PORT=%q\n' "$SERVER_PORT"
    printf 'TLS_SERVER=%q\n' "$TLS_SERVER"
    printf 'REALITY_DOMAIN=%q\n' "$REALITY_DOMAIN"
    printf 'REALITY_PRIVATE=%q\n' "$REALITY_PRIVATE"
    printf 'REALITY_PUBLIC=%q\n' "$REALITY_PUBLIC"
    printf 'REALITY_SHORT_ID=%q\n' "$REALITY_SHORT_ID"
    printf 'REALITY_COMPAT_PORT=%q\n' "$REALITY_COMPAT_PORT"
    printf 'REALITY_PQC_PORT=%q\n' "$REALITY_PQC_PORT"
    printf 'VLESS_WS_COMPAT_PORT=%q\n' "$VLESS_WS_COMPAT_PORT"
    printf 'VLESS_WS_PQC_PORT=%q\n' "$VLESS_WS_PQC_PORT"
    printf 'VLESS_XHTTP_COMPAT_PORT=%q\n' "$VLESS_XHTTP_COMPAT_PORT"
    printf 'VLESS_XHTTP_PQC_PORT=%q\n' "$VLESS_XHTTP_PQC_PORT"
    printf 'NGINX_PORT=%q\n' "$NGINX_PORT"
    printf 'ENABLE_REALITY_COMPAT=%q\n' "$ENABLE_REALITY_COMPAT"
    printf 'ENABLE_REALITY_PQC=%q\n' "$ENABLE_REALITY_PQC"
    printf 'ENABLE_WS_COMPAT=%q\n' "$ENABLE_WS_COMPAT"
    printf 'ENABLE_WS_PQC=%q\n' "$ENABLE_WS_PQC"
    printf 'ENABLE_XHTTP=%q\n' "$ENABLE_XHTTP"
    printf 'ENABLE_VLESS_PQC=%q\n' "$ENABLE_VLESS_PQC"
    printf 'VLESS_PQC_STRICT=%q\n' "$VLESS_PQC_STRICT"
    printf 'VLESS_PQC_REQUIRE_PREFIX=%q\n' "$VLESS_PQC_REQUIRE_PREFIX"
    printf 'VLESS_PQC_DISABLE_0RTT=%q\n' "$VLESS_PQC_DISABLE_0RTT"
    printf 'VLESS_PQC_RESUME=%q\n' "$VLESS_PQC_RESUME"
    printf 'VLESS_PQC_CLIENT_RTT=%q\n' "$VLESS_PQC_CLIENT_RTT"
    printf 'VLESS_PQC_DECRYPTION=%q\n' "$VLESS_PQC_DECRYPTION"
    printf 'VLESS_PQC_ENCRYPTION=%q\n' "$VLESS_PQC_ENCRYPTION"
    printf 'PQC_READY=%q\n' "$PQC_READY"
    printf 'ARGO_DOMAIN=%q\n' "$ARGO_DOMAIN"
    printf 'ARGO_TOKEN=%q\n' "$ARGO_TOKEN"
    printf 'ARGO_EDGE_IP_VERSION=%q\n' "$ARGO_EDGE_IP_VERSION"
    printf 'UPSTREAM_RAW_URL=%q\n' "$UPSTREAM_RAW_URL"
  } > "$CUSTOM_FILE"
  chmod 600 "$CUSTOM_FILE" 2>/dev/null || true
}

url_encode() {
  local s=${1:-}
  if have jq; then
    jq -rn --arg v "$s" '$v|@uri'
  elif have python3; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$s"
  else
    printf '%s' "$s" | sed 's/ /%20/g; s#/#%2F#g; s/:/%3A/g; s/&/%26/g; s/?/%3F/g; s/=/%3D/g; s/+/%2B/g'
  fi
}

json_str() { jq -Rn --arg v "$1" '$v'; }

uri_host() {
  local h="$1"
  if [[ "$h" == *:* && "$h" != \[*\] ]]; then
    printf '[%s]' "$h"
  else
    printf '%s' "$h"
  fi
}

sanitize_ws_path() {
  WS_PATH=$(printf '%s' "$WS_PATH" | sed 's#^/##; s#[^A-Za-z0-9._@-]#-#g')
  [ -n "$WS_PATH" ] || WS_PATH='argox'
}

random_token() {
  if have openssl; then
    openssl rand -hex 12
  else
    tr -dc 'a-f0-9' </dev/urandom | head -c 24
  fi
}

random_short_id() {
  if have openssl; then
    openssl rand -hex 8
  else
    tr -dc 'a-f0-9' </dev/urandom | head -c 16
  fi
}

random_uuid() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  elif have uuidgen; then
    uuidgen | tr 'A-Z' 'a-z'
  else
    printf '%08x-%04x-%04x-%04x-%012x\n' "$RANDOM$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM$RANDOM$RANDOM"
  fi
}

pkg_install() {
  truthy "$DRY_RUN" && { info "dry-run: skip package installation"; return 0; }
  local pkgs=(curl wget unzip jq ca-certificates openssl procps iproute2 lsof)
  truthy "$INSTALL_NGINX_PACKAGE" && pkgs+=(nginx)
  if have apt-get; then
    apt-get update -y
    apt-get install -y "${pkgs[@]}"
  elif have dnf; then
    dnf install -y "${pkgs[@]}"
  elif have yum; then
    yum install -y "${pkgs[@]}"
  elif have apk; then
    apk add --no-cache bash curl wget unzip jq ca-certificates openssl procps iproute2 lsof nginx
  else
    fatal "不支持的系统包管理器；请先安装 curl/wget/unzip/jq/nginx。"
  fi
}

arch_assets() {
  local a
  a=$(uname -m)
  case "$a" in
    x86_64|amd64) XRAY_ASSET='Xray-linux-64.zip'; CLOUDFLARED_ASSET='cloudflared-linux-amd64' ;;
    aarch64|arm64) XRAY_ASSET='Xray-linux-arm64-v8a.zip'; CLOUDFLARED_ASSET='cloudflared-linux-arm64' ;;
    armv7l|armv7*) XRAY_ASSET='Xray-linux-arm32-v7a.zip'; CLOUDFLARED_ASSET='cloudflared-linux-arm' ;;
    s390x) XRAY_ASSET='Xray-linux-s390x.zip'; CLOUDFLARED_ASSET='cloudflared-linux-s390x' ;;
    *) fatal "当前架构 $a 暂不支持。" ;;
  esac
}

download_file() {
  local url=$1 out=$2
  curl -fL --retry 3 --connect-timeout 20 -o "$out" "$url" || wget -O "$out" "$url"
}

stop_existing_services_for_upgrade() {
  truthy "$DRY_RUN" && return 0
  # v0.6.2: avoid "Text file busy" when replacing a binary that is already running.
  if have systemctl; then
    systemctl stop "$SERVICE_CF" "$SERVICE_NGINX" "$SERVICE_XRAY" >/dev/null 2>&1 || true
  fi
  if have pkill; then
    pkill -f "$CLOUDFLARED_BIN" >/dev/null 2>&1 || true
    pkill -f "$XRAY_BIN" >/dev/null 2>&1 || true
  fi
  sleep 1
}

atomic_install_executable() {
  local src=$1 dst=$2 mode=${3:-700}
  local tmpdst="${dst}.new.$$"
  install -m "$mode" "$src" "$tmpdst"
  mv -f "$tmpdst" "$dst"
  chmod "$mode" "$dst" 2>/dev/null || true
}

install_xray() {
  truthy "$DRY_RUN" && { info "dry-run: skip xray download"; return 0; }
  arch_assets
  safe_mkdirs
  local tmp zip
  tmp=$(mktemp -d)
  zip="$tmp/xray.zip"
  info "下载 Xray-core: $XRAY_ASSET"
  download_file "https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_ASSET}" "$zip"
  unzip -qo "$zip" -d "$tmp/xray"
  [ -x "$tmp/xray/xray" ] || chmod +x "$tmp/xray/xray" 2>/dev/null || true
  [ -x "$tmp/xray/xray" ] || fatal "Xray 解压失败：未找到可执行文件。"
  atomic_install_executable "$tmp/xray/xray" "$XRAY_BIN" 700
  [ -f "$tmp/xray/geoip.dat" ] && install -m 600 "$tmp/xray/geoip.dat" "$BIN_DIR/geoip.dat" || true
  [ -f "$tmp/xray/geosite.dat" ] && install -m 600 "$tmp/xray/geosite.dat" "$BIN_DIR/geosite.dat" || true
  rm -rf "$tmp"
}

install_cloudflared() {
  truthy "$DRY_RUN" && { info "dry-run: skip cloudflared download"; return 0; }
  arch_assets
  safe_mkdirs
  local tmp
  tmp=$(mktemp -d)
  info "下载 cloudflared: $CLOUDFLARED_ASSET"
  download_file "https://github.com/cloudflare/cloudflared/releases/latest/download/${CLOUDFLARED_ASSET}" "$tmp/cloudflared"
  chmod 700 "$tmp/cloudflared"
  atomic_install_executable "$tmp/cloudflared" "$CLOUDFLARED_BIN" 700
  rm -rf "$tmp"
}

port_in_use() {
  local p=$1
  if have ss; then
    ss -lntup 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:|\\])${p}$"
  elif have lsof; then
    lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1
  else
    return 1
  fi
}

choose_free_port() {
  local p=$1 min=${2:-10000}
  while port_in_use "$p"; do p=$((p+1)); [ "$p" -gt 65530 ] && p=$min; done
  printf '%s' "$p"
}

normalize_ports() {
  truthy "$DRY_RUN" && return 0
  REALITY_COMPAT_PORT=$(choose_free_port "$REALITY_COMPAT_PORT" 30000)
  REALITY_PQC_PORT=$(choose_free_port "$REALITY_PQC_PORT" 30001)
  VLESS_WS_COMPAT_PORT=$(choose_free_port "$VLESS_WS_COMPAT_PORT" 30010)
  VLESS_WS_PQC_PORT=$(choose_free_port "$VLESS_WS_PQC_PORT" 30011)
  VLESS_XHTTP_COMPAT_PORT=$(choose_free_port "$VLESS_XHTTP_COMPAT_PORT" 30012)
  VLESS_XHTTP_PQC_PORT=$(choose_free_port "$VLESS_XHTTP_PQC_PORT" 30013)
  NGINX_PORT=$(choose_free_port "$NGINX_PORT" 8080)
}

get_public_ip() {
  [ -n "$SERVER_IP" ] && return 0
  truthy "$DRY_RUN" && { SERVER_IP='203.0.113.10'; return 0; }
  SERVER_IP=$(curl -fsSL --max-time 8 https://api.ipify.org 2>/dev/null || true)
  [ -n "$SERVER_IP" ] || SERVER_IP=$(curl -fsSL --max-time 8 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]' || true)
  [ -n "$SERVER_IP" ] || SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -n "$SERVER_IP" ] || fatal "无法获取服务器 IP，请通过 SERVER_IP=... 指定。"
}

reality_connect_addr() {
  if [ -n "$REALITY_DOMAIN" ]; then printf '%s' "$REALITY_DOMAIN"; else printf '%s' "$SERVER_IP"; fi
}

generate_reality_keys() {
  if [ -n "$REALITY_PRIVATE" ] && [ -n "$REALITY_PUBLIC" ]; then return 0; fi
  if truthy "$DRY_RUN"; then
    REALITY_PRIVATE=${REALITY_PRIVATE:-'DRYRUN_PRIVATE_KEY_PLACEHOLDER'}
    REALITY_PUBLIC=${REALITY_PUBLIC:-'DRYRUN_PUBLIC_KEY_PLACEHOLDER'}
    return 0
  fi
  [ -x "$XRAY_BIN" ] || fatal "Xray 未安装，无法生成 Reality 密钥。"
  local out
  out=$($XRAY_BIN x25519 2>/dev/null || true)
  REALITY_PRIVATE=$(printf '%s\n' "$out" | awk -F': ' '/Private/{print $2; exit}' | awk '{print $NF}')
  REALITY_PUBLIC=$(printf '%s\n' "$out" | awk -F': ' '/Public/{print $2; exit}' | awk '{print $NF}')
  [ -n "$REALITY_PRIVATE" ] && [ -n "$REALITY_PUBLIC" ] || fatal "Reality 密钥生成失败。"
}

normalize_vless_pqc_server_ticket() {
  local v="$1" resume="${VLESS_PQC_RESUME:-600s}"
  if truthy "$VLESS_PQC_DISABLE_0RTT"; then
    v=$(printf '%s' "$v" | sed -E "s/\.(0rtt|1rtt)\./.${resume}./")
  fi
  printf '%s' "$v"
}

normalize_vless_pqc_client_ticket() {
  local v="$1" rtt="${VLESS_PQC_CLIENT_RTT:-1rtt}"
  if truthy "$VLESS_PQC_DISABLE_0RTT"; then rtt='1rtt'; fi
  v=$(printf '%s' "$v" | sed -E "s/\.[0-9]+(-[0-9]+)?s\./.${rtt}./")
  v=$(printf '%s' "$v" | sed -E "s/\.0rtt\./.${rtt}./")
  printf '%s' "$v"
}

prepare_vless_pqc() {
  PQC_READY='n'
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

  if [ -n "$VLESS_PQC_DECRYPTION" ] && [ -n "$VLESS_PQC_ENCRYPTION" ]; then
    VLESS_PQC_DECRYPTION=$(normalize_vless_pqc_server_ticket "$VLESS_PQC_DECRYPTION")
    VLESS_PQC_ENCRYPTION=$(normalize_vless_pqc_client_ticket "$VLESS_PQC_ENCRYPTION")
    if [[ "$VLESS_PQC_DECRYPTION" == ${VLESS_PQC_REQUIRE_PREFIX}.* && "$VLESS_PQC_ENCRYPTION" == ${VLESS_PQC_REQUIRE_PREFIX}.* ]]; then
      PQC_READY='y'
    else
      warn "vlessenc 输出不是 ${VLESS_PQC_REQUIRE_PREFIX}.*，已跳过 PQC profile。"
      VLESS_PQC_DECRYPTION=''
      VLESS_PQC_ENCRYPTION=''
    fi
  fi

  if ! truthy "$PQC_READY"; then
    if truthy "$VLESS_PQC_STRICT"; then
      fatal "Xray vlessenc 不可用或不支持 ML-KEM-768。可设置 VLESS_PQC_STRICT=n 先部署兼容版。"
    fi
    warn "未启用 PQC profile：当前 Xray 不支持 vlessenc 或未生成有效参数。兼容版会继续部署。"
  fi
}

xhttp_effective() {
  case "$ENABLE_XHTTP" in
    y|Y|yes|true|1) return 0 ;;
    n|N|no|false|0) return 1 ;;
    auto|AUTO|'') [ -n "$ARGO_DOMAIN" ] && [[ ! "$ARGO_DOMAIN" =~ trycloudflare\.com$ ]] && return 0 || return 1 ;;
    *) return 1 ;;
  esac
}

write_inbound_vless_reality() {
  local file=$1 tag=$2 port=$3 dec=$4
  jq -n \
    --arg tag "$tag" --arg id "$UUID" --arg dec "$dec" --arg dest "${TLS_SERVER}:443" --arg sni "$TLS_SERVER" --arg pk "$REALITY_PRIVATE" --arg sid "$REALITY_SHORT_ID" --argjson port "$port" \
    '{tag:$tag,listen:"0.0.0.0",port:$port,protocol:"vless",settings:{clients:[{id:$id,flow:"xtls-rprx-vision"}],decryption:$dec},streamSettings:{network:"tcp",security:"reality",realitySettings:{show:false,dest:$dest,xver:0,serverNames:[$sni],privateKey:$pk,shortIds:[$sid]}},sniffing:{enabled:true,destOverride:["http","tls","quic"],metadataOnly:false}}' \
    > "$file"
}

write_inbound_vless_ws() {
  local file=$1 tag=$2 port=$3 dec=$4 path=$5
  jq -n \
    --arg tag "$tag" --arg id "$UUID" --arg dec "$dec" --arg path "$path" --argjson port "$port" \
    '{tag:$tag,listen:"127.0.0.1",port:$port,protocol:"vless",settings:{clients:[{id:$id,level:0}],decryption:$dec},streamSettings:{network:"ws",security:"none",wsSettings:{path:$path}},sniffing:{enabled:true,destOverride:["http","tls","quic"],metadataOnly:false}}' \
    > "$file"
}

write_inbound_vless_xhttp() {
  local file=$1 tag=$2 port=$3 dec=$4 path=$5
  jq -n \
    --arg tag "$tag" --arg id "$UUID" --arg dec "$dec" --arg path "$path" --argjson port "$port" \
    '{tag:$tag,listen:"127.0.0.1",port:$port,protocol:"vless",settings:{clients:[{id:$id,level:0}],decryption:$dec},streamSettings:{network:"xhttp",security:"none",xhttpSettings:{path:$path,mode:"auto"}},sniffing:{enabled:true,destOverride:["http","tls","quic"],metadataOnly:false}}' \
    > "$file"
}

generate_xray_config() {
  safe_mkdirs
  local tmp
  tmp=$(mktemp -d)
  local n=0

  if truthy "$ENABLE_REALITY_COMPAT"; then
    n=$((n+1)); write_inbound_vless_reality "$tmp/$n.json" "${NODE_NAME} reality-vision-compat" "$REALITY_COMPAT_PORT" 'none'
  fi
  if truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY"; then
    n=$((n+1)); write_inbound_vless_reality "$tmp/$n.json" "${NODE_NAME} reality-vision-pqc" "$REALITY_PQC_PORT" "$VLESS_PQC_DECRYPTION"
  fi
  if truthy "$ENABLE_WS_COMPAT"; then
    n=$((n+1)); write_inbound_vless_ws "$tmp/$n.json" "${NODE_NAME} vless-ws-compat" "$VLESS_WS_COMPAT_PORT" 'none' "/${WS_PATH}-vl-c"
  fi
  if truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY"; then
    n=$((n+1)); write_inbound_vless_ws "$tmp/$n.json" "${NODE_NAME} vless-ws-pqc" "$VLESS_WS_PQC_PORT" "$VLESS_PQC_DECRYPTION" "/${WS_PATH}-vl-p"
  fi
  if xhttp_effective; then
    n=$((n+1)); write_inbound_vless_xhttp "$tmp/$n.json" "${NODE_NAME} vless-xhttp-cdn-compat" "$VLESS_XHTTP_COMPAT_PORT" 'none' "/${WS_PATH}-xh-c"
    if truthy "$PQC_READY"; then
      n=$((n+1)); write_inbound_vless_xhttp "$tmp/$n.json" "${NODE_NAME} vless-xhttp-cdn-pqc" "$VLESS_XHTTP_PQC_PORT" "$VLESS_PQC_DECRYPTION" "/${WS_PATH}-xh-p"
    fi
  fi
  [ "$n" -gt 0 ] || fatal "没有任何启用的 profile。"

  jq -s \
    --arg access "$LOG_DIR/access.log" --arg error "$LOG_DIR/error.log" \
    '{log:{access:$access,error:$error,loglevel:"warning"},inbounds:.,outbounds:[{tag:"direct",protocol:"freedom"},{tag:"blocked",protocol:"blackhole"}],routing:{domainStrategy:"AsIs",rules:[{type:"field",ip:["geoip:private"],outboundTag:"blocked"}]}}' \
    "$tmp"/*.json > "$CONFIG_FILE"
  rm -rf "$tmp"
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true

  if [ -x "$XRAY_BIN" ] && ! truthy "$DRY_RUN"; then
    if ! "$XRAY_BIN" run -test -config "$CONFIG_FILE" >/tmp/argox-mp-xray-test.log 2>&1; then
      cat /tmp/argox-mp-xray-test.log >&2 || true
      fatal "Xray 配置测试失败。"
    fi
  fi
}

nginx_ws_location() {
  local path=$1 port=$2
  cat <<EOF
    location = ${path} {
      proxy_pass http://127.0.0.1:${port};
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_redirect off;
      proxy_buffering off;
      proxy_read_timeout 1h;
      proxy_send_timeout 1h;
    }
EOF
}

nginx_xhttp_location() {
  local path=$1 port=$2
  cat <<EOF
    location ^~ ${path} {
      proxy_pass http://127.0.0.1:${port};
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_redirect off;
      proxy_buffering off;
      proxy_request_buffering off;
      proxy_max_temp_file_size 0;
      client_max_body_size 0;
      proxy_read_timeout 1h;
      proxy_send_timeout 1h;
    }
EOF
}

generate_nginx_config() {
  safe_mkdirs
  local locs=''
  if truthy "$ENABLE_WS_COMPAT"; then locs+=$(nginx_ws_location "/${WS_PATH}-vl-c" "$VLESS_WS_COMPAT_PORT"); locs+=$'\n'; fi
  if truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY"; then locs+=$(nginx_ws_location "/${WS_PATH}-vl-p" "$VLESS_WS_PQC_PORT"); locs+=$'\n'; fi
  if xhttp_effective; then
    locs+=$(nginx_xhttp_location "/${WS_PATH}-xh-c" "$VLESS_XHTTP_COMPAT_PORT"); locs+=$'\n'
    if truthy "$PQC_READY"; then locs+=$(nginx_xhttp_location "/${WS_PATH}-xh-p" "$VLESS_XHTTP_PQC_PORT"); locs+=$'\n'; fi
  fi

  cat > "$NGINX_CONF" <<EOF
user root;
worker_processes auto;
error_log ${LOG_DIR}/nginx_error.log warn;
pid ${RUN_DIR}/nginx.pid;

events { worker_connections 1024; }

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log off;
  sendfile on;
  tcp_nopush on;
  keepalive_timeout 65;
  server_tokens off;

  server {
    listen 127.0.0.1:${NGINX_PORT};
    server_name localhost;

    location = / {
      default_type text/plain;
      return 200 "${PROJECT_NAME} ${VERSION}\\n";
    }

${locs}

    location ~ ^/sub/${SUB_TOKEN}/(.+)$ {
      default_type text/plain;
      alias ${SUB_DIR}/\$1;
      add_header Cache-Control "no-store" always;
    }
  }
}
EOF
  chmod 600 "$NGINX_CONF" 2>/dev/null || true
  if have nginx && ! truthy "$DRY_RUN"; then
    nginx -t -c "$NGINX_CONF"
  fi
}

write_systemd_units() {
  truthy "$DRY_RUN" && { info "dry-run: skip systemd units"; return 0; }
  [ -d /etc/systemd/system ] || fatal "未检测到 systemd。"
  cat > "/etc/systemd/system/${SERVICE_XRAY}" <<EOF
[Unit]
Description=${PROJECT_NAME} - Xray
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORK_DIR}
ExecStart=${XRAY_BIN} run -config ${CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  cat > "/etc/systemd/system/${SERVICE_NGINX}" <<EOF
[Unit]
Description=${PROJECT_NAME} - Nginx local gateway
After=network-online.target ${SERVICE_XRAY}
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/usr/sbin/nginx -t -c ${NGINX_CONF}
ExecStart=/usr/sbin/nginx -c ${NGINX_CONF} -g 'daemon off;'
ExecReload=/usr/sbin/nginx -s reload -c ${NGINX_CONF}
ExecStop=/bin/kill -s QUIT \$MAINPID
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  local cf_cmd
  if [ -n "$ARGO_TOKEN" ]; then
    cf_cmd="${CLOUDFLARED_BIN} tunnel --edge-ip-version ${ARGO_EDGE_IP_VERSION} --no-autoupdate run --token ${ARGO_TOKEN}"
  else
    cf_cmd="${CLOUDFLARED_BIN} tunnel --edge-ip-version ${ARGO_EDGE_IP_VERSION} --no-autoupdate --url http://127.0.0.1:${NGINX_PORT}"
  fi
  cat > "/etc/systemd/system/${SERVICE_CF}" <<EOF
[Unit]
Description=${PROJECT_NAME} - Cloudflare Tunnel
After=network-online.target ${SERVICE_NGINX}
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORK_DIR}
ExecStart=${cf_cmd}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$SERVICE_XRAY" "$SERVICE_NGINX" "$SERVICE_CF" >/dev/null
}

start_services() {
  truthy "$DRY_RUN" && { info "dry-run: skip service start"; return 0; }
  systemctl restart "$SERVICE_XRAY"
  systemctl restart "$SERVICE_NGINX"
  systemctl restart "$SERVICE_CF"
}

parse_trycloudflare_domain() {
  [ -n "$ARGO_DOMAIN" ] && return 0
  truthy "$DRY_RUN" && { ARGO_DOMAIN='example.trycloudflare.com'; return 0; }
  local d=''
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    d=$(journalctl -u "$SERVICE_CF" -n 120 --no-pager 2>/dev/null | grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' | tail -1 | sed 's#https://##' || true)
    [ -n "$d" ] && break
    sleep 2
  done
  [ -n "$d" ] && ARGO_DOMAIN="$d" || true
}

open_firewall() {
  truthy "$DRY_RUN" && return 0
  truthy "$AUTO_OPEN_FIREWALL" || return 0
  local ports=()
  truthy "$ENABLE_REALITY_COMPAT" && ports+=("${REALITY_COMPAT_PORT}/tcp")
  truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY" && ports+=("${REALITY_PQC_PORT}/tcp")
  if have ufw && ufw status 2>/dev/null | grep -qi active; then
    for p in "${ports[@]}"; do ufw allow "$p" comment 'argox-mp reality' >/dev/null 2>&1 || true; done
  fi
  if have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    for p in "${ports[@]}"; do firewall-cmd --permanent --add-port="$p" >/dev/null 2>&1 || true; done
    firewall-cmd --reload >/dev/null 2>&1 || true
  fi
}

build_reality_uri() {
  local label=$1 port=$2 enc=$3
  local addr name encq sniq
  addr=$(uri_host "$(reality_connect_addr)")
  name=$(url_encode "${NODE_NAME} ${label}")
  encq=$(url_encode "$enc")
  sniq=$(url_encode "$TLS_SERVER")
  printf 'vless://%s@%s:%s?encryption=%s&flow=xtls-rprx-vision&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&spx=%%2F&type=tcp&headerType=none#%s\n' \
    "$UUID" "$addr" "$port" "$encq" "$sniq" "$REALITY_PUBLIC" "$REALITY_SHORT_ID" "$name"
}

build_ws_uri() {
  local label=$1 suffix=$2 enc=$3
  [ -n "$ARGO_DOMAIN" ] || return 0
  local server host name encq pathq sniq
  host="$ARGO_DOMAIN"
  server="${SERVER:-$ARGO_DOMAIN}"
  name=$(url_encode "${NODE_NAME} ${label}")
  encq=$(url_encode "$enc")
  pathq=$(url_encode "/${WS_PATH}-${suffix}")
  sniq=$(url_encode "$host")
  printf 'vless://%s@%s:%s?encryption=%s&security=tls&sni=%s&fp=chrome&type=ws&host=%s&path=%s#%s\n' \
    "$UUID" "$server" "$SERVER_PORT" "$encq" "$sniq" "$host" "$pathq" "$name"
}

build_xhttp_uri() {
  local label=$1 suffix=$2 enc=$3
  [ -n "$ARGO_DOMAIN" ] || return 0
  local server host name encq pathq sniq
  host="$ARGO_DOMAIN"
  server="${SERVER:-$ARGO_DOMAIN}"
  name=$(url_encode "${NODE_NAME} ${label}")
  encq=$(url_encode "$enc")
  pathq=$(url_encode "/${WS_PATH}-${suffix}")
  sniq=$(url_encode "$host")
  printf 'vless://%s@%s:%s?encryption=%s&security=tls&sni=%s&fp=chrome&alpn=h2%%2Chttp%%2F1.1&type=xhttp&host=%s&path=%s&mode=auto#%s\n' \
    "$UUID" "$server" "$SERVER_PORT" "$encq" "$sniq" "$host" "$pathq" "$name"
}

yaml_quote() {
  printf '%s' "$1" | sed "s/'/''/g; s/^/'/; s/$/'/"
}

generate_mihomo() {
  local f="$SUB_DIR/mihomo.yaml"
  local reality_addr
  reality_addr=$(reality_connect_addr)
  {
    echo 'mixed-port: 7890'
    echo 'allow-lan: false'
    echo 'mode: rule'
    echo 'log-level: info'
    echo 'proxies:'
    if truthy "$ENABLE_REALITY_COMPAT"; then
      cat <<EOF
  - name: $(yaml_quote "${NODE_NAME} Reality Vision Compat")
    type: vless
    server: $(yaml_quote "$reality_addr")
    port: ${REALITY_COMPAT_PORT}
    uuid: $(yaml_quote "$UUID")
    udp: true
    flow: xtls-rprx-vision
    network: tcp
    tls: true
    servername: $(yaml_quote "$TLS_SERVER")
    client-fingerprint: chrome
    reality-opts:
      public-key: $(yaml_quote "$REALITY_PUBLIC")
      short-id: $(yaml_quote "$REALITY_SHORT_ID")
    encryption: none
EOF
    fi
    if truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY"; then
      cat <<EOF
  - name: $(yaml_quote "${NODE_NAME} Reality Vision PQC")
    type: vless
    server: $(yaml_quote "$reality_addr")
    port: ${REALITY_PQC_PORT}
    uuid: $(yaml_quote "$UUID")
    udp: true
    flow: xtls-rprx-vision
    network: tcp
    tls: true
    servername: $(yaml_quote "$TLS_SERVER")
    client-fingerprint: chrome
    reality-opts:
      public-key: $(yaml_quote "$REALITY_PUBLIC")
      short-id: $(yaml_quote "$REALITY_SHORT_ID")
    encryption: $(yaml_quote "$VLESS_PQC_ENCRYPTION")
EOF
    fi
    if [ -n "$ARGO_DOMAIN" ]; then
      if truthy "$ENABLE_WS_COMPAT"; then
        cat <<EOF
  - name: $(yaml_quote "${NODE_NAME} VLESS WS Compat")
    type: vless
    server: $(yaml_quote "${SERVER:-$ARGO_DOMAIN}")
    port: ${SERVER_PORT}
    uuid: $(yaml_quote "$UUID")
    udp: true
    tls: true
    servername: $(yaml_quote "$ARGO_DOMAIN")
    client-fingerprint: chrome
    network: ws
    ws-opts:
      path: $(yaml_quote "/${WS_PATH}-vl-c")
      headers:
        Host: $(yaml_quote "$ARGO_DOMAIN")
    encryption: none
EOF
      fi
      if truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY"; then
        cat <<EOF
  - name: $(yaml_quote "${NODE_NAME} VLESS WS PQC")
    type: vless
    server: $(yaml_quote "${SERVER:-$ARGO_DOMAIN}")
    port: ${SERVER_PORT}
    uuid: $(yaml_quote "$UUID")
    udp: true
    tls: true
    servername: $(yaml_quote "$ARGO_DOMAIN")
    client-fingerprint: chrome
    network: ws
    ws-opts:
      path: $(yaml_quote "/${WS_PATH}-vl-p")
      headers:
        Host: $(yaml_quote "$ARGO_DOMAIN")
    encryption: $(yaml_quote "$VLESS_PQC_ENCRYPTION")
EOF
      fi
    fi
    echo 'proxy-groups:'
  } > "$f.tmp1"

  # Rebuild group names from the generated proxy section only.
  local names
  names=$(awk '/^proxy-groups:/{exit} /^  - name:/{sub(/^  - name: /, ""); print}' "$f.tmp1")
  awk '/^proxy-groups:/{exit} {print}' "$f.tmp1" > "$f"
  {
    echo 'proxy-groups:'
    echo '  - name: Auto'
    echo '    type: select'
    echo '    proxies:'
    while IFS= read -r n; do [ -n "$n" ] && echo "      - $n"; done <<< "$names"
    echo 'rules:'
    echo '  - MATCH,Auto'
  } >> "$f"
  rm -f "$f.tmp1" "$f.tmp" 2>/dev/null || true
}

generate_subscriptions() {
  safe_mkdirs
  : > "$SUB_DIR/all.txt"
  : > "$SUB_DIR/compat.txt"
  : > "$SUB_DIR/pqc.txt"
  : > "$SUB_DIR/reality.txt"
  : > "$SUB_DIR/cdn.txt"

  if truthy "$ENABLE_REALITY_COMPAT"; then
    local u
    u=$(build_reality_uri 'Reality Vision Compat' "$REALITY_COMPAT_PORT" 'none')
    printf '%s\n' "$u" | tee -a "$SUB_DIR/all.txt" "$SUB_DIR/compat.txt" "$SUB_DIR/reality.txt" >/dev/null
  fi
  if truthy "$ENABLE_REALITY_PQC" && truthy "$PQC_READY"; then
    local u
    u=$(build_reality_uri 'Reality Vision PQC' "$REALITY_PQC_PORT" "$VLESS_PQC_ENCRYPTION")
    printf '%s\n' "$u" | tee -a "$SUB_DIR/all.txt" "$SUB_DIR/pqc.txt" "$SUB_DIR/reality.txt" >/dev/null
  fi
  if [ -n "$ARGO_DOMAIN" ]; then
    if truthy "$ENABLE_WS_COMPAT"; then
      local u
      u=$(build_ws_uri 'VLESS WS Compat' 'vl-c' 'none')
      printf '%s\n' "$u" | tee -a "$SUB_DIR/all.txt" "$SUB_DIR/compat.txt" "$SUB_DIR/cdn.txt" >/dev/null
    fi
    if truthy "$ENABLE_WS_PQC" && truthy "$PQC_READY"; then
      local u
      u=$(build_ws_uri 'VLESS WS PQC' 'vl-p' "$VLESS_PQC_ENCRYPTION")
      printf '%s\n' "$u" | tee -a "$SUB_DIR/all.txt" "$SUB_DIR/pqc.txt" "$SUB_DIR/cdn.txt" >/dev/null
    fi
    if xhttp_effective; then
      local u
      u=$(build_xhttp_uri 'VLESS XHTTP CDN Compat' 'xh-c' 'none')
      printf '%s\n' "$u" | tee -a "$SUB_DIR/all.txt" "$SUB_DIR/compat.txt" "$SUB_DIR/cdn.txt" >/dev/null
      if truthy "$PQC_READY"; then
        u=$(build_xhttp_uri 'VLESS XHTTP CDN PQC' 'xh-p' "$VLESS_PQC_ENCRYPTION")
        printf '%s\n' "$u" | tee -a "$SUB_DIR/all.txt" "$SUB_DIR/pqc.txt" "$SUB_DIR/cdn.txt" >/dev/null
      fi
    fi
  fi

  base64 -w0 "$SUB_DIR/all.txt" > "$SUB_DIR/all.base64" 2>/dev/null || base64 "$SUB_DIR/all.txt" > "$SUB_DIR/all.base64" || true
  generate_mihomo
  chmod -R go+rX "$SUB_DIR" 2>/dev/null || true
}

show_links() {
  load_custom
  parse_trycloudflare_domain || true
  generate_subscriptions
  save_custom
  echo
  green "======== ${PROJECT_NAME} ${VERSION} ========"
  echo "Work dir: ${WORK_DIR}"
  echo "Reality addr: $(reality_connect_addr)"
  echo "Reality SNI : ${TLS_SERVER}"
  echo "Reality sid : ${REALITY_SHORT_ID:-none}"
  echo "Argo domain : ${ARGO_DOMAIN:-not-ready-yet}"
  echo "PQC ready   : ${PQC_READY}"
  echo
  echo "--- compat.txt ---"
  cat "$SUB_DIR/compat.txt" || true
  echo
  if [ -s "$SUB_DIR/pqc.txt" ]; then
    echo "--- pqc.txt ---"
    cat "$SUB_DIR/pqc.txt" || true
    echo
  fi
  if [ -n "$ARGO_DOMAIN" ]; then
    echo "--- remote subscriptions ---"
    echo "https://${ARGO_DOMAIN}/sub/${SUB_TOKEN}/compat.txt"
    echo "https://${ARGO_DOMAIN}/sub/${SUB_TOKEN}/pqc.txt"
    echo "https://${ARGO_DOMAIN}/sub/${SUB_TOKEN}/all.txt"
    echo "https://${ARGO_DOMAIN}/sub/${SUB_TOKEN}/mihomo.yaml"
    echo
  fi
}

write_shortcut() {
  truthy "$DRY_RUN" && return 0
  cat > /usr/local/bin/argox-mp <<EOF
#!/usr/bin/env bash
set -e
if [ -s ${WORK_DIR}/argox.sh ]; then
  exec bash ${WORK_DIR}/argox.sh "\$@"
fi
if command -v curl >/dev/null 2>&1; then
  exec bash <(curl -fsSL ${UPSTREAM_RAW_URL}) "\$@"
elif command -v wget >/dev/null 2>&1; then
  exec bash <(wget -qO- ${UPSTREAM_RAW_URL}) "\$@"
else
  echo "argox-mp: missing saved script and curl/wget" >&2
  exit 1
fi
EOF
  chmod +x /usr/local/bin/argox-mp
}

copy_self() {
  truthy "$DRY_RUN" && return 0
  safe_mkdirs
  local self="${BASH_SOURCE[0]}"
  if [ -f "$self" ]; then
    install -m 700 "$self" "$WORK_DIR/argox.sh"
    return 0
  fi
  if [ -n "${UPSTREAM_RAW_URL:-}" ]; then
    local tmp
    tmp=$(mktemp)
    if download_file "$UPSTREAM_RAW_URL" "$tmp" >/dev/null 2>&1 && [ -s "$tmp" ]; then
      install -m 700 "$tmp" "$WORK_DIR/argox.sh"
      rm -f "$tmp"
      return 0
    fi
    rm -f "$tmp" 2>/dev/null || true
  fi
  warn "无法保存当前脚本到 ${WORK_DIR}/argox.sh；但快捷命令会回退到远程脚本。"
}

install_all() {
  need_root
  load_custom
  sanitize_ws_path
  safe_mkdirs
  [ -n "$UUID" ] || UUID=$(random_uuid)
  [ -n "$SUB_TOKEN" ] || SUB_TOKEN=$(random_token)
  [ -n "$REALITY_SHORT_ID" ] || REALITY_SHORT_ID=$(random_short_id)
  get_public_ip
  [ -n "$REALITY_DOMAIN" ] || REALITY_DOMAIN=''

  pkg_install
  stop_existing_services_for_upgrade
  install_xray
  install_cloudflared
  normalize_ports
  generate_reality_keys
  prepare_vless_pqc
  generate_xray_config
  generate_nginx_config
  open_firewall
  save_custom
  copy_self
  write_shortcut
  write_systemd_units
  start_services
  parse_trycloudflare_domain || true
  generate_subscriptions
  save_custom
  show_links
  green "安装完成。管理命令：argox-mp status | argox-mp links | argox-mp restart | argox-mp uninstall"
}

status_all() {
  load_custom
  echo "${PROJECT_NAME} ${VERSION}"
  echo "Work dir: $WORK_DIR"
  if have systemctl; then
    systemctl --no-pager --full status "$SERVICE_XRAY" "$SERVICE_NGINX" "$SERVICE_CF" || true
  else
    echo "systemctl not found"
  fi
}

restart_all() {
  need_root
  load_custom
  generate_subscriptions || true
  save_custom || true
  systemctl restart "$SERVICE_XRAY" "$SERVICE_NGINX" "$SERVICE_CF"
  show_links
}

logs_all() {
  if have journalctl; then
    journalctl -u "$SERVICE_XRAY" -u "$SERVICE_NGINX" -u "$SERVICE_CF" -n 200 --no-pager
  else
    tail -n 200 "$LOG_DIR"/*.log 2>/dev/null || true
  fi
}

uninstall_all() {
  need_root
  if have systemctl; then
    systemctl disable --now "$SERVICE_CF" "$SERVICE_NGINX" "$SERVICE_XRAY" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/${SERVICE_CF}" "/etc/systemd/system/${SERVICE_NGINX}" "/etc/systemd/system/${SERVICE_XRAY}"
    systemctl daemon-reload || true
  fi
  rm -f /usr/local/bin/argox-mp
  rm -rf "$WORK_DIR"
  green "已卸载 ${PROJECT_NAME}。"
}

dry_run() {
  DRY_RUN=y
  WORK_DIR=${DRY_RUN_WORK_DIR:-/tmp/argox-mp-dryrun}
  BIN_DIR="$WORK_DIR/bin"; SUB_DIR="$WORK_DIR/subscribe"; LOG_DIR="$WORK_DIR/logs"; RUN_DIR="$WORK_DIR/run"; CUSTOM_FILE="$WORK_DIR/custom.env"; XRAY_BIN="$BIN_DIR/xray"; CLOUDFLARED_BIN="$BIN_DIR/cloudflared"; CONFIG_FILE="$WORK_DIR/config.json"; NGINX_CONF="$WORK_DIR/nginx.conf"
  rm -rf "$WORK_DIR"
  safe_mkdirs
  UUID=${UUID:-$(random_uuid)}
  SUB_TOKEN=${SUB_TOKEN:-$(random_token)}
  SERVER_IP=${SERVER_IP:-203.0.113.10}
  ARGO_DOMAIN=${ARGO_DOMAIN:-example.trycloudflare.com}
  REALITY_PRIVATE=${REALITY_PRIVATE:-DRYRUN_PRIVATE_KEY_PLACEHOLDER}
  REALITY_PUBLIC=${REALITY_PUBLIC:-DRYRUN_PUBLIC_KEY_PLACEHOLDER}
  REALITY_SHORT_ID=${REALITY_SHORT_ID:-0123456789abcdef}
  PQC_READY=n
  sanitize_ws_path
  prepare_vless_pqc
  generate_xray_config
  generate_nginx_config
  generate_subscriptions
  save_custom
  jq empty "$CONFIG_FILE"
  nginx -t -c "$NGINX_CONF" >/dev/null 2>&1 || true
  green "dry-run OK: $WORK_DIR"
  find "$WORK_DIR" -maxdepth 3 -type f | sort
}


doctor_all() {
  load_custom
  echo "${PROJECT_NAME} ${VERSION} doctor"
  echo "Work dir: $WORK_DIR"
  echo "Reality: $(reality_connect_addr):${REALITY_COMPAT_PORT} sid=${REALITY_SHORT_ID:-none} sni=${TLS_SERVER}"
  echo "Argo domain: ${ARGO_DOMAIN:-not-saved-yet}"
  echo
  if have systemctl; then
    systemctl is-active "$SERVICE_XRAY" "$SERVICE_NGINX" "$SERVICE_CF" 2>/dev/null || true
    systemctl --no-pager --full status "$SERVICE_XRAY" "$SERVICE_NGINX" "$SERVICE_CF" | sed -n '1,120p' || true
  fi
  echo
  echo "--- listening ports ---"
  ss -lntup 2>/dev/null | grep -E ":(${REALITY_COMPAT_PORT}|${REALITY_PQC_PORT}|${NGINX_PORT}|${VLESS_WS_COMPAT_PORT}|${VLESS_WS_PQC_PORT})\b" || true
  echo
  echo "--- local nginx root ---"
  curl -fsS --max-time 5 "http://127.0.0.1:${NGINX_PORT}/" || true
  echo
  echo "--- local websocket path health (HTTP status expected 400/404/426, not connection refused) ---"
  curl -sS -o /dev/null -w 'ws-compat http_status=%{http_code}\n' --max-time 5 "http://127.0.0.1:${NGINX_PORT}/${WS_PATH}-vl-c" || true
  echo
  parse_trycloudflare_domain || true
  if [ -n "$ARGO_DOMAIN" ]; then
    echo "--- cloudflare tunnel public root ---"
    curl -k -sS -o /dev/null -w "https://${ARGO_DOMAIN}/ http_status=%{http_code}\n" --max-time 12 "https://${ARGO_DOMAIN}/" || true
  fi
  echo
  echo "--- recent logs ---"
  journalctl -u "$SERVICE_XRAY" -u "$SERVICE_NGINX" -u "$SERVICE_CF" -n 80 --no-pager 2>/dev/null || true
}

usage() {
  cat <<EOF
${PROJECT_NAME} ${VERSION}

Usage:
  bash argox.sh -l | install          Install / reinstall
  bash argox.sh -f config.conf        Load env config then install
  bash argox.sh -n | links            Show links
  bash argox.sh -s | status           Show services
  bash argox.sh -r | restart          Restart services
  bash argox.sh logs                  Show logs
  bash argox.sh doctor                Run connectivity diagnostics
  bash argox.sh -u | uninstall        Uninstall
  bash argox.sh --dry-run             Generate configs locally for validation

Common environment variables:
  ARGO_TOKEN='Cloudflare tunnel token'
  ARGO_DOMAIN='proxy.example.com'
  REALITY_DOMAIN='reality.example.com'
  TLS_SERVER='www.microsoft.com'
  ENABLE_XHTTP=y
  VLESS_PQC_STRICT=y
EOF
}

main() {
  local cmd=${1:-install}
  case "$cmd" in
    -f|--config)
      [ -n "${2:-}" ] || fatal "缺少配置文件路径。"
      # shellcheck disable=SC1090
      . "$2"
      install_all
      ;;
    -l|install|--install) install_all ;;
    -n|links|--links) show_links ;;
    -s|status|--status) status_all ;;
    -r|restart|--restart) restart_all ;;
    logs|--logs) logs_all ;;
    doctor|--doctor) doctor_all ;;
    -u|uninstall|--uninstall) uninstall_all ;;
    --dry-run) dry_run ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
