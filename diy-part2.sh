#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.

# Modify default IP
sed -i 's/192.168.1.1/192.168.0.1/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 拉取最新 lucky 包
git clone https://github.com/gdy666/luci-app-lucky.git package/lucky

# 拉取最新 nikki 包
git clone -b main https://github.com/nikkinikki-org/OpenWrt-nikki.git package/nikki

# 添加 BBR 优化 sysctl 配置文件
mkdir -p package/base-files/files/etc/sysctl.d
cat << 'EOF' > package/base-files/files/etc/sysctl.d/99-bbr.conf
########## BBR 拥塞控制 ##########
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

########## TCP 加速 ##########
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_mtu_probing = 1

########## 大内存缓冲优化 (≥2GB RAM) ##########
net.core.optmem_max = 65535
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608

########## 吞吐+低延迟优化 ##########
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

########## NAT & 连接跟踪优化 ##########
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_established = 1800
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120

########## IPv6 优化 ##########
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.use_tempaddr = 0
net.ipv6.conf.all.use_tempaddr = 0
net.ipv6.conf.default.accept_ra = 2
net.ipv6.conf.all.accept_ra = 2

########## 安全性优化 ##########
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF

# RE-CS-07 / IPQ60xx 无 Wi-Fi，禁用全部 hostapd / wpad / supplicant 相关包
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
    sed -i "/^CONFIG_PACKAGE_${pkg}=y/d" .config
    sed -i "/^CONFIG_PACKAGE_${pkg}=m/d" .config
    sed -i "/^# CONFIG_PACKAGE_${pkg} is not set/d" .config
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
  done

  echo "===== Wireless packages disabled for RE-CS-07 ====="
  grep -nE "CONFIG_PACKAGE_(wpad|hostapd|wpa-supplicant|wpa-cli|eapol-test|wireless-regdb)" .config || true
else
  echo "WARNING: .config not found, skip disabling wireless packages"
fi
