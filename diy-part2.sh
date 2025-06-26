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

# 确保脚本在超级用户权限下运行
if [ $(id -u) -ne 0 ]; then
    echo "此脚本需要 root 权限，请使用 sudo 运行"
    exit 1
fi

echo "安装 opkg 和 uci 工具..."
# 安装 opkg 和 uci
if ! command -v opkg &> /dev/null; then
    echo "opkg 未安装，正在安装..."
    # 安装 opkg（根据 OpenWrt 版本选择合适的命令）
    opkg update && opkg install opkg uci
else
    echo "opkg 已安装"
fi

echo "安装防火墙服务..."
# 确保防火墙服务已安装
if ! command -v firewall &> /dev/null; then
    echo "防火墙未安装，正在安装..."
    opkg update && opkg install firewall
else
    echo "防火墙服务已安装"
fi

# 设置 sysctl 参数
echo "配置 sysctl 参数..."
echo "net.ipv4.tcp_congestion_control = bbr" | tee -a /etc/sysctl.conf
echo "net.core.default_qdisc = fq" | tee -a /etc/sysctl.conf

# 应用配置
sysctl -p

# 添加防火墙规则
echo "添加防火墙规则 'Lucky'..."
uci add firewall rule
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].name='Lucky'
uci set firewall.@rule[-1].src_port='53381-53399'
uci set firewall.@rule[-1].target='ACCEPT'

# 重启防火墙服务以应用规则
/etc/init.d/firewall restart

echo "BBR 拥塞控制已启用并保存到 sysctl 配置文件"
echo "防火墙规则 'Lucky' 已添加，允许端口 53381-53399 的流量通过。"
