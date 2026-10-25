#!/bin/bash
#
# File name: diy-part2.sh
# Description: After Update feeds (JDCloud RE-CS-07 2GB RAM: PPE Hardware Offload + Nikki + Lucky)
#

set -euo pipefail

# 修改默认 LAN 地址
sed -i 's/192.168.1.1/192.168.0.1/g' \
  package/base-files/files/bin/config_generate

# =========================================================
# 拉取第三方插件（先清理 feeds 潜在同名目录避免索引冲突）
# =========================================================

# Lucky
rm -rf feeds/packages/net/lucky feeds/luci/applications/luci-app-lucky package/lucky
git clone --depth=1 \
  https://github.com/gdy666/luci-app-lucky.git \
  package/lucky

# Nikki
rm -rf feeds/packages/net/nikki feeds/luci/applications/luci-app-nikki package/nikki
git clone --depth=1 -b main \
  https://github.com/nikkinikki-org/OpenWrt-nikki.git \
  package/nikki

# =========================================================
# BBR 与 PPE 网络参数优化（适配 IPQ60xx 2GB RAM 满血配置）
# =========================================================

mkdir -p package/base-files/files/etc/sysctl.d

cat << 'EOF' > package/base-files/files/etc/sysctl.d/99-bbr.conf
########## BBR congestion control ##########
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

########## Socket buffers for high-BDP links (16MB cap for 2GB RAM) ##########
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

########## EDMA / PPE NAPI poll budget ##########
net.core.netdev_max_backlog = 16384
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 8000

########## TCP tuning ##########
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_mtu_probing = 1

########## TCP resilience ##########
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

########## NAT and adaptive conntrack baseline ##########
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 120

########## IPv6 baseline ##########
net.ipv6.conf.default.use_tempaddr = 0
net.ipv6.conf.all.use_tempaddr = 0

########## Security baseline ##########
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

########## Policy routing / Nikki TUN & TProxy ##########
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF

# =========================================================
# 兼容 PPE Flow Offloading 与 Nikki TUN 模式
# =========================================================

# 在 fw4 forward 链触发 flow add @ft 之前放行 TUN 接口流量，
# 确保直连流量进 PPE 硬件加速的同时，切换到 TUN 模式也不会被 flowtable 误卸载断流
mkdir -p package/base-files/files/usr/share/nftables.d/chain-pre/forward

cat << 'EOF' > package/base-files/files/usr/share/nftables.d/chain-pre/forward/10-bypass-tun-flowoffload.nft
iifname { "nikki", "utun", "Meta", "tun*" } accept
oifname { "nikki", "utun", "Meta", "tun*" } accept
EOF

# =========================================================
# RE-CS-07 运行时策略与状态工具
# =========================================================

CUSTOM_FILES_DIR="${GITHUB_WORKSPACE:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}/files"

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

# 自动将 RE-CS-07 策略中的 Flow Offloading 修正为开启（激活 PPE 硬件加速）
sed -i "s/flow_offloading='0'/flow_offloading='1'/g; s/flow_offloading=\"0\"/flow_offloading=\"1\"/g" \
  package/base-files/files/etc/uci-defaults/99-re-cs-07 \
  package/base-files/files/etc/config/re_cs_07 2>/dev/null || true
sed -i "s/flow_offloading_hw='0'/flow_offloading_hw='1'/g; s/flow_offloading_hw=\"0\"/flow_offloading_hw=\"1\"/g" \
  package/base-files/files/etc/uci-defaults/99-re-cs-07 \
  package/base-files/files/etc/config/re_cs_07 2>/dev/null || true

# =========================================================
# 彻底精简无线组件与内核驱动（RE-CS-07 纯有线设备，无无线硬件）
# =========================================================

# 1. 从 target/linux/qualcommax/Makefile 与 include/target.mk 默认包列表中移除无线驱动与守护进程，
#    防止后续执行 make defconfig 时因为平台默认依赖而把无线包重新设为 =y
sed -i 's/kmod-ath11k-ahb//g; s/kmod-ath11k-pci//g; s/kmod-ath11k//g; s/ath11k-firmware-[^ ]*//g; s/wpad-[^ ]*//g; s/iwinfo//g' \
  target/linux/qualcommax/Makefile \
  target/linux/qualcommax/image/ipq60xx.mk \
  include/target.mk 2>/dev/null || true

disable_package() {
  local package_name="$1"

  sed -i "/^CONFIG_PACKAGE_${package_name}=y/d" .config
  sed -i "/^CONFIG_PACKAGE_${package_name}=m/d" .config
  sed -i "/^# CONFIG_PACKAGE_${package_name} is not set/d" .config
  echo "# CONFIG_PACKAGE_${package_name} is not set" >> .config
}

if [ -f .config ]; then
  # 2. 禁用全部无线用户态工具、802.11 协议栈 (mac80211/cfg80211) 与 ath11k 无线驱动/固件
  for pkg in \
    kmod-ath11k \
    kmod-ath11k-ahb \
    kmod-ath11k-pci \
    kmod-ath \
    kmod-mac80211 \
    kmod-cfg80211 \
    ath11k-firmware-ipq6018 \
    ipq-wifi-jdcloud_re-cs-07 \
    iw \
    iwinfo \
    libiwinfo \
    libiwinfo-data \
    libiwinfo-lua \
    ucode-mod-nl80211 \
    ucode-mod-wpa \
    wifi-scripts \
    wireless-regdb \
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
    eapol-test-wolfssl
  do
    disable_package "$pkg"
  done

  echo "===== All wireless drivers, 802.11 stack, and userspace packages disabled ====="
else
  echo "ERROR: .config not found"
  exit 1
fi
