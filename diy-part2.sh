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

#Change the default WAN to eth0
sed -i "s/net\/eth1/net\/eth0/g" package/base-files/files/etc/board.d/99-default_network
sed -i "s/wan 'eth1'/wan 'eth0'/g" package/base-files/files/etc/board.d/99-default_network
sed -i "s/lan 'eth0'/lan 'eth1'/g" package/base-files/files/etc/board.d/99-default_network

# Modify default IP
sed -i 's/192.168.1.1/192.168.0.1/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
git clone https://github.com/gdy666/luci-app-lucky.git package/luci-app-lucky
