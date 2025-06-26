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

# 确保 uci 工具已安装
echo "检查并安装 uci 工具..."
if ! command -v uci &> /dev/null
then
    echo "uci 未安装，正在安装..."
    opkg update
    opkg install uci
fi

# 确保防火墙服务已安装
echo "检查并安装防火墙服务..."
if ! [ -x "$(command -v /etc/init.d/firewall)" ]; then
    echo "防火墙服务未安装，正在安装..."
    opkg update
    opkg install firewall
fi
# 添加 BBR 拥塞控制到 sysctl 配置文件
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf > /dev/null
# 重新加载 sysctl 配置
sudo sysctl -p
echo "BBR 拥塞控制已启用并保存到 sysctl 配置文件"

# 添加防火墙规则
echo "添加防火墙规则 'Lucky'..."
uci add firewall rule
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].name='Lucky'
uci set firewall.@rule[-1].src_port='53381-53399'
uci set firewall.@rule[-1].target='ACCEPT'
# 提交防火墙配置
uci commit firewall
# 重新加载防火墙服务
/etc/init.d/firewall reload
echo "防火墙规则 'Lucky' 已添加，允许端口 53381-53399 的流量通过。"
