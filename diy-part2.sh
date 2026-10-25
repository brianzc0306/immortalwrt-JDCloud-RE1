#!/bin/bash
#
# File name: diy-part2.sh
# Description: After Update feeds (PPE Hardware Offload + Nikki)
# Target: JDCloud RE-CS-07, qualcommax/ipq60xx (IPQ6010, 4C, 2GB RAM)
#

set -euo pipefail

# =========================================================
# 基础检查
# =========================================================

[ -f include/target.mk ] || { echo "ERROR: include/target.mk not found"; exit 1; }
[ -f package/base-files/files/bin/config_generate ] || { echo "ERROR: config_generate not found"; exit 1; }

# 修改默认 LAN 地址
sed -i 's/192.168.1.1/192.168.0.1/g' \
  package/base-files/files/bin/config_generate

# =========================================================
# 拉取第三方插件（先清理 feeds 同名包避免冲突）
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
# BBR 与 PPE 网络参数优化（针对 2GB RAM / 4C 调整）
# =========================================================

mkdir -p package/base-files/files/etc/sysctl.d

cat << 'EOF' > package/base-files/files/etc/sysctl.d/99-bbr.conf
########## BBR congestion control ##########
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

########## Socket buffers (16MB cap, suitable for 2GB RAM) ##########
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

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

########## NAT / conntrack (2GB RAM) ##########
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 5
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 5
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 10
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 10
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 10
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 120
net.netfilter.nf_conntrack_icmp_timeout = 15

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
# RE-CS-07 运行时策略与状态工具
# =========================================================
# 说明：不再自动改写 flow_offloading，由用户手动在 LuCI/SSH 中开启。

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

# =========================================================
# 精简无线组件（RE-CS-07 无无线功能）
# =========================================================

# 用通用正则剥离 target.mk 中所有无线相关默认包，避免 make defconfig 重新拉起
sed -i -E 's/\b(wpad[^[:space:]]*|hostapd[^[:space:]]*|wpa-supplicant[^[:space:]]*|wireless-regdb)\b//g' \
  include/target.mk

disable_package() {
  local package_name="$1"

  sed -i "/^CONFIG_PACKAGE_${package_name}=y/d" .config
  sed -i "/^CONFIG_PACKAGE_${package_name}=m/d" .config
  sed -i "/^# CONFIG_PACKAGE_${package_name} is not set/d" .config
  # 确保 .config 末尾有换行，避免追加内容拼到上一行
  [ -n "$(tail -c1 .config)" ] && echo >> .config
  echo "# CONFIG_PACKAGE_${package_name} is not set" >> .config
}

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
else
  echo "ERROR: .config not found"
  exit 1
fi

# =========================================================
# 编译优化与可选组件（.config 追加）
# =========================================================

# 确保 .config 末尾有换行
[ -n "$(tail -c1 .config)" ] && echo >> .config

# LTO + gc-sections：同时减小体积并提升性能
# 注意：极少数包可能因 LTO 链接失败，届时可在对应 Makefile 中加 PKG_BUILD_FLAGS:=no-lto
sed -i '/^CONFIG_USE_LTO=/d' .config
echo "CONFIG_USE_LTO=y" >> .config

sed -i '/^CONFIG_USE_GC_SECTIONS=/d' .config
echo "CONFIG_USE_GC_SECTIONS=y" >> .config

# zram：2GB 设备上作为 Nikki 规则集/瞬时连接峰值的低延迟缓冲
# 如不需要可注释掉以下两行
sed -i '/^CONFIG_PACKAGE_zram-swap=/d' .config
echo "CONFIG_PACKAGE_zram-swap=y" >> .config

echo "===== Build optimizations applied (LTO / gc-sections / zram) ====="

# =========================================================
# 说明（不写入固件，仅注释）
# =========================================================
# 1. Flow Offloading 不在本脚本中自动开启。首次启动后请手动执行：
#      uci set firewall.@defaults[0].flow_offloading='1'
#      uci set firewall.@defaults[0].flow_offloading_hw='1'
#      uci commit firewall && /etc/init.d/firewall restart
#    或在 LuCI → 网络 → 防火墙 → 常规设置 中勾选。
#
# 2. Nikki 建议使用 TPROXY 模式（TCP+UDP 均支持，优于 TUN 的上下文切换开销）：
#    在 Nikki 的 LuCI 设置中将代理模式设为 TPROXY。
#
# 3. 本机已确认 EDMA 中断分散（RX→CPU1，TX→CPU2）且 NAPI 线程落在对应核心。
#    如需核查，可运行：
#      cat /proc/interrupts | grep edma
#      taskset -pc <NAPI线程TID>
#    若 NAPI 线程意外回到 CPU0，可手动绑定：
#      taskset -pc 1 <rx_tid>
#      taskset -pc 2 <tx_tid>
#    通常固件已处理，无需持久化脚本。
