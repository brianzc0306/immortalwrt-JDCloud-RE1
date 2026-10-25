#!/bin/bash
#
# File name: diy-part2.sh
# Description: After Update feeds (PPE Hardware Offload + Nikki)
# Target: JDCloud RE-CS-07, qualcommax/ipq60xx (IPQ6010, 4C, 2GB RAM)

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
# 默认 131072，与 re_cs_07 配置 conntrack_low 一致；
# 峰值由 re-cs-07-monitor 按需抬到 262144（conntrack_high）。
net.netfilter.nf_conntrack_max = 131072
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
# rp_filter 用 2（loose）代替 0：TPROXY 兼容，同时保留防源地址欺骗
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
EOF

# =========================================================
# RE-CS-07 运行时策略与状态工具
# =========================================================
# 说明：flow_offloading 由 files/etc/uci-defaults/99-re-cs-07 首启强制关闭
#       （避免绕过 Nikki TPROXY），本脚本不再自动改写。
# files/ 目录缺失时只警告并跳过，不中断后续流程。

CUSTOM_FILES_DIR="${GITHUB_WORKSPACE:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}/files"

if [ -d "$CUSTOM_FILES_DIR" ]; then
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
else
  echo "WARN: custom files directory not found: $CUSTOM_FILES_DIR (skip RE-CS-07 runtime tools)"
fi

# =========================================================
# 精简无线组件（确认不用无线再执行本段）
# =========================================================
# 说明：
#   * RE-CS-07 硬件本身带 2.4G/5G（ath11k），本段执行后无线接口将不可用。
#   * 本仓库 workflow 中 make defconfig 在 diy-part2 之后执行：
#     - include/target.mk 的 sed 有效，能阻止默认包被 defconfig 重新拉起；
#     - 下方 disable_package 写入的 "# ... is not set" 也会被 defconfig 保留。
#     两者互为双保险，可同时保留。
#   * 若还想省内存，ath11k 内核包属于设备级 DEVICE_PACKAGES
#     （target/linux/qualcommax/image/ipq60xx.mk 中 re-cs-07 定义），
#     .config 关不掉，需改对应 .mk——见文末注释 4。

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
# PPE 硬件卸载组件（.config 追加，仅预留，不自动开启）
# =========================================================
# 说明：ipq60xx 当前源码走 PPE 路径（NSS/ECM 已弃用，勿再加 qca-nss-ecm / nss-firmware）。
#       kmod-nft-offload 是 nft flowtable offload 的内核模块，只有把
#       firewall flow_offloading(_hw) 置 1 时才会被使用。
#       【重要】Nikki TPROXY 运行期间必须保持 flow offloading 关闭
#       （files/etc/uci-defaults/99-re-cs-07 已处理），否则代理流量会绕过
#       nftables 直连泄漏。包名以 make menuconfig 搜 nft-offload 为准。

# 确保 .config 末尾有换行
[ -n "$(tail -c1 .config)" ] && echo >> .config

sed -i '/^CONFIG_PACKAGE_kmod-nft-offload=/d' .config
echo "CONFIG_PACKAGE_kmod-nft-offload=y" >> .config

# =========================================================
# 编译优化与可选组件（.config 追加）
# =========================================================

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

echo "===== Build optimizations applied (LTO / gc-sections / zram / nft-offload) ====="

# =========================================================
# 说明（不写入固件，仅注释）
# =========================================================
# 1. Flow Offloading 与 Nikki TPROXY 冲突，默认保持关闭（uci-defaults 已处理）。
#    - 只要 Nikki 在 TPROXY 模式运行，就不要开 flow_offloading，
#      卸载连接绕过 nftables，代理规则不生效、流量直连泄漏。
#    - 只有关闭/移除代理后才考虑开启：
#        uci set firewall.@defaults[0].flow_offloading='1'
#        uci set firewall.@defaults[0].flow_offloading_hw='1'
#        uci commit firewall && /etc/init.d/firewall restart
#    - 验证卸载是否生效：cat /proc/net/netfilter/nf_flowtable 或
#      dmesg | grep -i flow
#
# 2. Nikki 建议使用 TPROXY 模式（TCP+UDP 均支持，优于 TUN 的上下文切换开销）：
#    在 Nikki 的 LuCI 设置中将代理模式设为 TPROXY。
#
# 3. EDMA 中断分散（RX→CPU1，TX→CPU2）与 NAPI 线程绑定由固件处理；
#    如需核查可运行：
#      cat /proc/interrupts | grep edma
#      taskset -pc <NAPI线程TID>
#
# 4. （可选）若完全不需要无线且想省内存，把 ath11k 相关包从设备定义里去掉：
#    target/linux/qualcommax/image/ipq60xx.mk 中 re-cs-07 的 DEVICE_PACKAGES
#    （如 kmod-ath11k-pci / ath11k-firmware-qcn*），.config 无法关闭这类强制包。
