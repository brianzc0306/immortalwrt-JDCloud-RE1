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

#!/bin/bash

# ===== BBR 拥塞控制配置 =====
BBR_CONF="files/etc/sysctl.d/99-bbr.conf"
mkdir -p files/etc/sysctl.d

# 创建/覆盖 BBR 配置
cat > "$BBR_CONF" << EOF
# BBR 拥塞控制优化
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 系统性能优化
vm.max_map_count = 262144
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
vm.mmap_rnd_bits = 16
EOF

echo "✅ BBR 拥塞控制及系统优化配置已写入 $BBR_CONF"

# ===== 防火墙规则添加 =====
FIREWALL_CONF="files/etc/config/firewall"
mkdir -p files/etc/config

# 检测防火墙配置是否存在
if [ -f "$FIREWALL_CONF" ]; then
    echo "ℹ️ 检测到已存在的防火墙配置: $FIREWALL_CONF"
    echo "ℹ️ 将在现有配置基础上追加 Lucky 端口规则"
    BACKUP_FILE="${FIREWALL_CONF}.pre-lucky"
    cp "$FIREWALL_CONF" "$BACKUP_FILE"
    echo "ℹ️ 已创建配置文件备份: $BACKUP_FILE"
else
    echo "ℹ️ 未检测到防火墙配置，将创建基础配置"
    # 创建基础防火墙配置
    cat > "$FIREWALL_CONF" << 'EOF'
config defaults
    option syn_flood '1'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'REJECT'

config zone
    option name 'lan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'
    option network 'lan'

config zone
    option name 'wan'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'
    option network 'wan wan6'
EOF
fi

# 添加 Lucky 端口规则
echo "
# Lucky 端口规则 (由 diy-part2.sh 添加)
config rule
    option name 'Lucky'
    option src 'wan'
    option proto 'tcp udp'
    option dest_port '53381-53399'
    option target 'ACCEPT'" >> "$FIREWALL_CONF"

# 检查规则是否添加成功
if grep -q "Lucky" "$FIREWALL_CONF"; then
    echo "✅ 防火墙规则 'Lucky' 已成功添加，允许端口 53381-53399 的流量通过"
else
    echo "❌ 警告：未能成功添加防火墙规则，请手动检查 $FIREWALL_CONF"
    exit 1
fi

# 最终状态报告
echo ""
echo "==============================="
echo "配置完成状态报告:"
echo "1. BBR 配置: $( [ -f "$BBR_CONF" ] && echo "已安装" || echo "缺失" )"
echo "2. 防火墙配置: $( [ -f "$FIREWALL_CONF" ] && echo "已存在" || echo "缺失" )"
echo "3. Lucky 规则: $(grep -q "Lucky" "$FIREWALL_CONF" && echo "已添加" || echo "未检测到")"
echo "==============================="
