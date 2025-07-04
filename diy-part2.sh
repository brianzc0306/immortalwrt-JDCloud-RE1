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

# 确保必要的目录存在
mkdir -p ./package/base-files/files/etc/init.d
mkdir -p ./package/base-files/files/etc/rc.d
mkdir -p ./package/base-files/files/usr/bin
mkdir -p ./package/base-files/files/etc/nftables.d

# 创建 BBR 优化服务脚本
cat > ./package/base-files/files/etc/init.d/bbr-optimize << 'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

apply_lucky_firewall_rules() {
    # 检查规则是否存在
    if ! nft list chain inet fw4 input | grep -q '53381-53399'; then
        echo "添加Lucky防火墙规则 (53381-53399)..."
        nft add rule inet fw4 input iifname "wan" tcp dport 53381-53399 counter accept comment "Lucky-TCP"
        nft add rule inet fw4 input iifname "wan" udp dport 53381-53399 counter accept comment "Lucky-UDP"
    fi

    # 保存规则到持久化配置
    if [ -x /usr/sbin/fw4 ]; then
        /usr/sbin/fw4 -q apply
        echo "防火墙规则已保存"
    fi
}

start_service() {
    # 确保内核模块已加载
    modprobe tcp_bbr 2>/dev/null
    
    # 应用BBR优化参数
    echo "应用网络优化参数..."
    sysctl -w net.core.default_qdisc=fq
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    sysctl -w net.ipv4.tcp_fastopen=3
    sysctl -w net.core.rmem_max=16777216
    sysctl -w net.core.wmem_max=16777216
    sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
    sysctl -w net.ipv4.tcp_wmem="4096 16384 16777216"
    sysctl -w net.ipv4.tcp_mtu_probing=1
    
    # 持久化设置到配置文件
    grep -q "net.core.default_qdisc" /etc/sysctl.conf || echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_congestion_control" /etc/sysctl.conf || echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_fastopen" /etc/sysctl.conf || echo "net.ipv4.tcp_fastopen = 3" >> /etc/sysctl.conf
    grep -q "net.core.rmem_max" /etc/sysctl.conf || echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
    grep -q "net.core.wmem_max" /etc/sysctl.conf || echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_rmem" /etc/sysctl.conf || echo "net.ipv4.tcp_rmem = 4096 87380 16777216" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_wmem" /etc/sysctl.conf || echo "net.ipv4.tcp_wmem = 4096 16384 16777216" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_mtu_probing" /etc/sysctl.conf || echo "net.ipv4.tcp_mtu_probing = 1" >> /etc/sysctl.conf
    
    
    # 添加Lucky防火墙规则
    apply_lucky_firewall_rules
    
    # 验证结果
    echo "当前拥塞控制算法: $(sysctl -n net.ipv4.tcp_congestion_control)"
    echo "BBR模块状态: $(lsmod | grep -c bbr)"
    echo "Lucky端口状态:"
    nft list chain inet fw4 input | grep -A 2 'Lucky-'
}

stop_service() {
    return 0
}
EOF

# 设置脚本权限
chmod 0755 ./package/base-files/files/etc/init.d/bbr-optimize

# 创建启动链接 (确保目录存在)
ln -sf ../init.d/bbr-optimize ./package/base-files/files/etc/rc.d/S99bbr-optimize 2>/dev/null || {
    mkdir -p ./package/base-files/files/etc/rc.d
    ln -sf ../init.d/bbr-optimize ./package/base-files/files/etc/rc.d/S99bbr-optimize
}

# 预配置 sysctl.conf
mkdir -p ./package/base-files/files/etc
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
mkdir -p ./package/base-files/files/usr/bin
cat > ./package/base-files/files/usr/bin/check-bbr << 'EOF'
#!/bin/sh

echo "===== BBR 优化状态检查 ====="
echo "拥塞控制算法: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '未设置')"
echo "队列策略: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo '未设置')"
echo "TCP Fast Open: $(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo '未设置')"
echo "接收缓冲区: $(sysctl -n net.core.rmem_max 2>/dev/null || echo '未设置')"
echo "发送缓冲区: $(sysctl -n net.core.wmem_max 2>/dev/null || echo '未设置')"
echo "BBR模块状态: $(lsmod | grep -c bbr)"

echo "===== Lucky 防火墙状态 ====="
echo "IPv4/6 规则:"
nft list chain inet fw4 input 2>/dev/null | grep -A 2 'Lucky-' || echo "未找到Lucky规则"
echo "============================"
EOF

chmod 0755 ./package/base-files/files/usr/bin/check-bbr

# 在登录提示中添加检查命令提示
mkdir -p ./package/base-files/files/etc
cat >> ./package/base-files/files/etc/banner << 'EOF'

  BBR 优化已集成，刷机后自动生效！
  Lucky 防火墙规则已添加 (53381-53399)
  使用命令检查状态: check-bbr
EOF

# 添加 nftables 规则描述
mkdir -p ./package/base-files/files/etc/nftables.d
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
