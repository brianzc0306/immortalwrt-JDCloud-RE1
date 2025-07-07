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
# BBR 核心参数
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# 优化参数（可选但推荐）
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
EOF
