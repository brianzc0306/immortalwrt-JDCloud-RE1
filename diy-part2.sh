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


# 移动自定义文件
[ -e files ] && mv files openwrt/files

# =====================
# 配置 BBR 加速 
# =====================
echo "配置 BBR 加速..."

# 创建自定义 sysctl 配置文件
mkdir -p openwrt/package/base-files/files/etc/sysctl.d
cat > openwrt/package/base-files/files/etc/sysctl.d/60-bbr.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# =====================
# 添加防火墙规则 
# =====================
echo "添加防火墙规则..."

# 创建防火墙规则文件
mkdir -p openwrt/package/network/config/firewall/files
cat >> openwrt/package/network/config/firewall/files/firewall.config << 'EOF'

config rule
    option name 'Lucky'
    option src 'wan'
    option src_port '53381-53399'
    option proto 'tcp udp'
    option target 'ACCEPT'
EOF

echo "配置完成！"
