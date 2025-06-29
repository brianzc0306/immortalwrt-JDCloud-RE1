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


# ==================================================
# 添加 BBR 优化脚本到固件 (京东云无线宝专用)
# ==================================================

# 创建 BBR 优化服务脚本
cat > ./package/base-files/files/etc/init.d/bbr-optimize << 'EOF'
[上面完整的bbr-optimize脚本内容]
EOF

# 设置脚本权限
chmod 0755 ./package/base-files/files/etc/init.d/bbr-optimize

# 创建启动链接
ln -sf ../init.d/bbr-optimize ./package/base-files/files/etc/rc.d/S99bbr-optimize

# 预配置 sysctl.conf
cat >> ./package/base-files/files/etc/sysctl.conf << 'EOF'

# =====================================
# BBR 优化参数 (自动添加)
# =====================================
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_mtu_probing = 1
EOF

# 添加验证脚本
cat > ./package/base-files/files/usr/bin/check-bbr << 'EOF'
#!/bin/sh

echo "===== BBR 优化状态检查 ====="
echo "拥塞控制算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "队列策略: $(sysctl -n net.core.default_qdisc)"
echo "TCP Fast Open: $(sysctl -n net.ipv4.tcp_fastopen)"
echo "接收缓冲区: $(sysctl -n net.core.rmem_max)"
echo "发送缓冲区: $(sysctl -n net.core.wmem_max)"
echo "BBR模块状态: $(lsmod | grep -c bbr)"
echo "irqbalance状态: $(service irqbalance status | grep -c running)"

echo "===== Lucky 防火墙状态 ====="
echo "IPv4/6 规则:"
nft list chain inet fw4 input | grep -A 2 'Lucky-Rules'
echo "============================"
EOF

chmod 0755 ./package/base-files/files/usr/bin/check-bbr

# 在登录提示中添加检查命令提示
cat >> ./package/base-files/files/etc/banner << 'EOF'

  BBR 优化已集成，刷机后自动生效！
  Lucky 防火墙规则已添加 (53381-53399)
  使用命令检查状态: check-bbr
EOF

# 添加 nftables 规则描述（可选但推荐）
cat > ./package/base-files/files/etc/nftables.d/10-lucky-rules.nft << 'EOF'
# Lucky 端口规则
chain input {
    # Lucky-Rules (TCP)
    iifname "wan" tcp dport 53381-53399 counter accept comment "Lucky-TCP"
    
    # Lucky-Rules (UDP)
    iifname "wan" udp dport 53381-53399 counter accept comment "Lucky-UDP"
}
EOF

echo "BBR 优化和Lucky防火墙规则已成功集成到固件中"
