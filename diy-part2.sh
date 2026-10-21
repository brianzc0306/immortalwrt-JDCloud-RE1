
#!/bin/bash
#
# File name: diy-part2.sh
# Description: After Update feeds
# Supports official ImmortalWrt and Qualcomm NSS forks
#

set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}"
cd "$ROOT_DIR"

# ============================================================
# 修改默认 LAN 地址：兼容不同 ImmortalWRT 源码结构
# ============================================================

LAN_IP="192.168.0.1"
CONFIG_FILE="package/base-files/files/bin/config_generate"

if [ -f "$CONFIG_FILE" ]; then
  sed -i "s/192\.168\.1\.1/${LAN_IP}/g" "$CONFIG_FILE"
  echo "===== Default LAN IP updated in config_generate ====="
else
  echo "===== config_generate not found; using uci-defaults ====="

  mkdir -p package/base-files/files/etc/uci-defaults

  cat > package/base-files/files/etc/uci-defaults/99-default-lan-ip <<'EOF'
#!/bin/sh

LAN_IP="192.168.0.1"

if [ "$(uci -q get network.lan.ipaddr)" != "$LAN_IP" ]; then
    uci set network.lan.ipaddr="$LAN_IP"
    uci commit network
fi

exit 0
EOF

  chmod 0755 package/base-files/files/etc/uci-defaults/99-default-lan-ip

  echo "===== Default LAN IP will be set to ${LAN_IP} on first boot ====="
fi

# ============================================================
# 拉取第三方插件
# ============================================================

rm -rf package/lucky
git clone --depth=1 \
  https://github.com/gdy666/luci-app-lucky.git \
  package/lucky

rm -rf package/nikki
git clone --depth=1 -b main \
  https://github.com/nikkinikki-org/OpenWrt-nikki.git \
  package/nikki

# ============================================================
# BBR 与网络参数优化
# ============================================================

mkdir -p package/base-files/files/etc/sysctl.d

cat <<'EOF' > package/base-files/files/etc/sysctl.d/99-bbr.conf
# BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Socket buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP tuning
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_mtu_probing = 1

# TCP resilience
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

# Conntrack baseline
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120

# IPv6
net.ipv6.conf.default.use_tempaddr = 0
net.ipv6.conf.all.use_tempaddr = 0

# Security
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Policy routing / Nikki TUN
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF

# ============================================================
# RE-CS-07 自定义文件
# ============================================================

CUSTOM_FILES_DIR="$ROOT_DIR/files"

if [ ! -d "$CUSTOM_FILES_DIR" ]; then
  echo "ERROR: custom files directory not found: $CUSTOM_FILES_DIR"
  exit 1
fi

install -d \
  package/base-files/files/etc/config \
  package/base-files/files/etc/init.d \
  package/base-files/files/etc/uci-defaults \
  package/base-files/files/usr/bin \
  package/base-files/files/usr/sbin

install -m 0644 \
  "$CUSTOM_FILES_DIR/etc/config/re_cs_07" \
  package/base-files/files/etc/config/re_cs_07

install -m 0755 \
  "$CUSTOM_FILES_DIR/etc/init.d/re-cs-07-monitor" \
  package/base-files/files/etc/init.d/re-cs-07-monitor

install -m 0755 \
  "$CUSTOM_FILES_DIR/etc/uci-defaults/99-re-cs-07" \
  package/base-files/files/etc/uci-defaults/99-re-cs-07

install -m 0755 \
  "$CUSTOM_FILES_DIR/usr/bin/re-cs-07-status" \
  package/base-files/files/usr/bin/re-cs-07-status

install -m 0755 \
  "$CUSTOM_FILES_DIR/usr/sbin/re-cs-07-monitor" \
  package/base-files/files/usr/sbin/re-cs-07-monitor

# ============================================================
# 配置辅助函数
# ============================================================

disable_package() {
  local package_name="$1"

  # 避免同一个 CONFIG 项重复追加
  sed -i \
    "/^CONFIG_PACKAGE_${package_name}=y$/d;
     /^CONFIG_PACKAGE_${package_name}=m$/d;
     /^# CONFIG_PACKAGE_${package_name} is not set$/d" \
    .config

  echo "# CONFIG_PACKAGE_${package_name} is not set" >> .config
}

# ============================================================
# 精简无线组件
# ============================================================

if [ -f .config ]; then
  for pkg in \
    wpad \
    wpad-basic \
    wpad-basic-mbedtls \
    wpad-basic-openssl \
    wpad-basic-wolfssl \
    wpad-mbedtls \
    wpad-openssl \
    wpad-wolfssl \
    wpad-mini \
    wpad-mesh \
    wpad-mesh-openssl \
    wpad-mesh-wolfssl \
    hostapd \
    hostapd-basic \
    hostapd-basic-mbedtls \
    hostapd-basic-openssl \
    hostapd-basic-wolfssl \
    hostapd-mbedtls \
    hostapd-openssl \
    hostapd-wolfssl \
    hostapd-mini \
    hostapd-common \
    hostapd-utils \
    wpa-supplicant \
    wpa-supplicant-basic \
    wpa-supplicant-mini \
    wpa-supplicant-mbedtls \
    wpa-supplicant-openssl \
    wpa-supplicant-wolfssl \
    wpa-supplicant-p2p \
    wpa-supplicant-mesh-openssl \
    wpa-supplicant-mesh-wolfssl \
    wpa-cli \
    eapol-test \
    eapol-test-openssl \
    eapol-test-wolfssl \
    wireless-regdb
  do
    disable_package "$pkg"
  done

  echo "===== Wireless packages disabled ====="

  # ==========================================================
  # NSS 兼容性检测
  # 只有源码中存在传统 NSS 驱动时，才处理 NSS 专用模块。
  # 不会为官方主线凭空启用不存在的 NSS 软件包。
  # ==========================================================

  if grep -Rqs \
    'Package/kmod-qca-nss-drv' \
    package feeds \
    --include='Makefile' 2>/dev/null; then

    echo "===== Traditional NSS package detected ====="

    for mod in \
      nss-eip-firmware \
      kmod-qca-nss-crypto \
      kmod-qca-nss-drv-gre \
      kmod-qca-nss-drv-eogremgr \
      kmod-qca-nss-drv-map-t \
      kmod-qca-nss-drv-vxlanmgr \
      kmod-qca-nss-drv-wifi-meshmgr \
      kmod-qca-nss-drv-pptp \
      kmod-qca-nss-drv-l2tpv2 \
      kmod-qca-nss-drv-tun6rd \
      kmod-qca-nss-drv-tunipip6 \
      kmod-qca-nss-drv-igs \
      kmod-qca-nss-drv-lag-mgr \
      kmod-qca-nss-drv-mirror \
      kmod-qca-nss-drv-qdisc
    do
      disable_package "$mod"
    done

    echo "===== Optional NSS modules disabled ====="
    echo "===== Core NSS packages are not forcibly disabled ====="

  else
    echo "===== Traditional NSS driver not found in source ====="
    echo "===== Skipping NSS-specific package configuration ====="
    echo "===== Official-mainline build does not imply NSS acceleration ====="
  fi

else
  echo "ERROR: .config not found"
  exit 1
fi

# ============================================================
# 目标设备检查
# ============================================================

if ! grep -q \
  '^CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-07=y$' \
  .config; then
  echo "WARNING: RE-CS-07 target is not selected yet."
  echo "Run make defconfig and verify the final target configuration."
fi

echo "===== diy-part2.sh completed ====="
