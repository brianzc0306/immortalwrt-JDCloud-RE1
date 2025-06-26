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

# 添加 BBR 配置到 /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 立即应用 BBR 设置
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 重新加载 sysctl 配置以生效
sysctl -p

echo "BBR 拥塞控制已启用并保存到 sysctl 配置文件"

# 添加防火墙规则：允许从 wan 接口，端口范围为 53381-53399 的流量
uci add firewall rule
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].name='Lucky'
uci set firewall.@rule[-1].src_port='53381-53399'
uci set firewall.@rule[-1].target='ACCEPT'

# 提交防火墙配置
uci commit firewall

# 重启防火墙服务使规则生效
/etc/init.d/firewall restart

echo "防火墙规则 'Lucky' 已添加，允许端口 53381-53399 的流量通过。"
