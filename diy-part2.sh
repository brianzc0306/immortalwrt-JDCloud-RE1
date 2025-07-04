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

# 添加 BBR 优化脚本
cat << 'EOF' >> package/base-files/files/etc/init.d/bbr
#!/bin/sh /etc/rc.common
START=99

start() {
    logger -t bbr "Enabling TCP BBR..."
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
}
EOF

chmod +x package/base-files/files/etc/init.d/bbr
