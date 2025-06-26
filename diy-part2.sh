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

# 添加 BBR 拥塞控制到 sysctl 配置文件
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf > /dev/null
# 添加 fq 队列调度器配置到 sysctl 配置文件
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf > /dev/null
# 重新加载 sysctl 配置
sudo sysctl -p
# 输出配置生效
echo "BBR 拥塞控制已启用并保存到 sysctl 配置文件"
