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

# 创建开机启动脚本
cat > ./package/base-files/files/etc/init.d/enable_bbr << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    modprobe tcp_bbr

    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    sysctl -w net.ipv4.tcp_fastopen=3
    sysctl -w net.ipv4.tcp_mtu_probing=1
    sysctl -w net.ipv4.tcp_window_scaling=1

    sysctl -w net.ipv4.tcp_rmem="4096 87380 6291456"
    sysctl -w net.ipv4.tcp_wmem="4096 16384 4194304"
    sysctl -w net.core.rmem_max=6291456
    sysctl -w net.core.wmem_max=4194304

    # 持久化
    cat > /etc/sysctl.d/99-bbr.conf << SYSCTL_EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 6291456
net.ipv4.tcp_wmem = 4096 16384 4194304
net.core.rmem_max = 6291456
net.core.wmem_max = 4194304
SYSCTL_EOF
}

EOF

chmod +x ./package/base-files/files/etc/init.d/enable_bbr

# 设置开机自动启用
echo "/etc/init.d/enable_bbr enable" >> ./package/base-files/files/etc/rc.local
