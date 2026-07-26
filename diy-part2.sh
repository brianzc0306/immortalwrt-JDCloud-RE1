#!/bin/bash
#
# File name: diy-part2.sh
# Description: After Update feeds
#

set -euo pipefail

# 修改默认 LAN 地址
sed -i 's/192.168.1.1/192.168.0.1/g' \
  package/base-files/files/bin/config_generate

# 修改默认主题
# sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' \
#   feeds/luci/collections/luci/Makefile


# ============================================================
# 拉取第三方插件
# ============================================================

# Lucky
rm -rf package/lucky
git clone --depth=1 \
  https://github.com/gdy666/luci-app-lucky.git \
  package/lucky

# Lucky 的应用日志是内存环形缓冲；关闭重复的 init 启停日志。
# 上游目前读取 logger 选项但未使用，因此在构建时补上开关判断。
sed -i \
  's/config_get_bool logger $1 logger 1/config_get_bool logger $1 logger 0/' \
  package/lucky/lucky/files/lucky.init
sed -i \
  's|^[[:space:]]*logger -t lucky -p warn "$1"|   [ "${logger:-0}" = "1" ] \&\& logger -t lucky -p warn "$1"|' \
  package/lucky/lucky/files/lucky.init
sed -i \
  "s/option logger '1'/option logger '0'/" \
  package/lucky/lucky/files/luckyuci

if ! grep -Fq 'logger:-0' package/lucky/lucky/files/lucky.init || \
   ! grep -Fq "option logger '0'" package/lucky/lucky/files/luckyuci; then
  echo "ERROR: failed to apply Lucky logging policy"
  exit 1
fi

# Nikki
rm -rf package/nikki
git clone --depth=1 -b main \
  https://github.com/nikkinikki-org/OpenWrt-nikki.git \
  package/nikki

# Optional OpenAppFilter test build. Stable builds do not fetch or select OAF.
FIRMWARE_FLAVOR="${FIRMWARE_FLAVOR:-stable}"

case "$FIRMWARE_FLAVOR" in
  stable)
    ;;
  oaf-test)
    OAF_REPO_URL="${OAF_REPO_URL:-https://github.com/destan19/OpenAppFilter.git}"
    OAF_COMMIT="${OAF_COMMIT:-a189ad85e8fb461318533941963f0e2975274a19}"

    # ImmortalWrt's packages feed also provides open-app-filter. Keeping that
    # package together with the pinned upstream tree creates duplicate
    # appfilter/kmod-oaf definitions and a Kconfig self-dependency.
    for duplicate_oaf_path in \
      package/feeds/packages/open-app-filter \
      feeds/packages/net/open-app-filter
    do
      if [ -e "$duplicate_oaf_path" ] || [ -L "$duplicate_oaf_path" ]; then
        echo "Removing duplicate feed package: $duplicate_oaf_path"
        rm -rf -- "$duplicate_oaf_path"
      fi

      if [ -e "$duplicate_oaf_path" ] || [ -L "$duplicate_oaf_path" ]; then
        echo "ERROR: duplicate OpenAppFilter feed package still exists: $duplicate_oaf_path"
        exit 1
      fi
    done

    rm -rf package/OpenAppFilter
    git init package/OpenAppFilter
    git -C package/OpenAppFilter remote add origin "$OAF_REPO_URL"
    git -C package/OpenAppFilter fetch --depth=1 origin "$OAF_COMMIT"
    git -C package/OpenAppFilter checkout --detach FETCH_HEAD

    if [ "$(git -C package/OpenAppFilter rev-parse HEAD)" != "$OAF_COMMIT" ]; then
      echo "ERROR: OpenAppFilter checkout does not match pinned commit"
      exit 1
    fi

    if ! grep -Fq '2006 梦幻西游:' \
      package/OpenAppFilter/open-app-filter/files/feature.cfg; then
      echo "ERROR: pinned OpenAppFilter feature library lacks 梦幻西游 (ID 2006)"
      exit 1
    fi

    if ! grep -Fq "option enable '0'" \
      package/OpenAppFilter/open-app-filter/files/appfilter.config || \
       ! grep -Fq "option disable_hnat '0'" \
      package/OpenAppFilter/open-app-filter/files/appfilter.config; then
      echo "ERROR: unexpected OpenAppFilter safe defaults"
      exit 1
    fi


    echo 'CONFIG_PACKAGE_luci-app-oaf=y' >> .config
    ;;
  *)
    echo "ERROR: unsupported build variant: $FIRMWARE_FLAVOR"
    exit 1
    ;;
esac

# ============================================================
# BBR 与网络参数优化
# ============================================================

mkdir -p package/base-files/files/etc/sysctl.d

cat << 'EOF' > package/base-files/files/etc/sysctl.d/99-bbr.conf
########## BBR congestion control ##########
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

########## TCP tuning ##########
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_mtu_probing = 1

########## TCP resilience ##########
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

########## NAT and adaptive conntrack baseline ##########
# The runtime monitor raises this to 262144 at 75% actual usage.
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120

########## IPv6 baseline ##########
net.ipv6.conf.default.use_tempaddr = 0
net.ipv6.conf.all.use_tempaddr = 0

########## Security baseline ##########
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

########## Policy routing / Nikki TUN ##########
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF


# ============================================================
# RE-CS-07 运行时策略与状态工具
# ============================================================

CUSTOM_FILES_DIR="${GITHUB_WORKSPACE:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}/files"

if [ ! -d "$CUSTOM_FILES_DIR" ]; then
  echo "ERROR: custom files directory not found: $CUSTOM_FILES_DIR"
  exit 1
fi

install -d \
  package/base-files/files/etc/config \
  package/base-files/files/etc/init.d \
  package/base-files/files/etc/uci-defaults \
  package/base-files/files/usr/bin \
  package/base-files/files/usr/sbin

install -m 0644 \
  "$CUSTOM_FILES_DIR/etc/config/re_cs_07" \
  package/base-files/files/etc/config/re_cs_07
install -m 0755 \
  "$CUSTOM_FILES_DIR/etc/init.d/re-cs-07-monitor" \
  package/base-files/files/etc/init.d/re-cs-07-monitor
install -m 0755 \
  "$CUSTOM_FILES_DIR/etc/uci-defaults/99-re-cs-07" \
  package/base-files/files/etc/uci-defaults/99-re-cs-07
install -m 0755 \
  "$CUSTOM_FILES_DIR/usr/bin/re-cs-07-status" \
  package/base-files/files/usr/bin/re-cs-07-status
install -m 0755 \
  "$CUSTOM_FILES_DIR/usr/sbin/re-cs-07-monitor" \
  package/base-files/files/usr/sbin/re-cs-07-monitor


# ============================================================
# 精简无线组件和 NSS 隧道模块
# ============================================================

disable_package() {
  local package_name="$1"

  sed -i "/^CONFIG_PACKAGE_${package_name}=y/d" .config
  sed -i "/^CONFIG_PACKAGE_${package_name}=m/d" .config
  sed -i "/^# CONFIG_PACKAGE_${package_name} is not set/d" .config

  echo "# CONFIG_PACKAGE_${package_name} is not set" >> .config
}

if [ -f .config ]; then

  # RE-CS-07 无无线功能
  for pkg in \
    wpad \
    wpad-basic \
    wpad-basic-mbedtls \
    wpad-basic-openssl \
    wpad-basic-wolfssl \
    wpad-mbedtls \
    wpad-openssl \
    wpad-wolfssl \
    wpad-mini \
    wpad-mesh \
    wpad-mesh-openssl \
    wpad-mesh-wolfssl \
    hostapd \
    hostapd-basic \
    hostapd-basic-mbedtls \
    hostapd-basic-openssl \
    hostapd-basic-wolfssl \
    hostapd-mbedtls \
    hostapd-openssl \
    hostapd-wolfssl \
    hostapd-mini \
    hostapd-common \
    hostapd-utils \
    wpa-supplicant \
    wpa-supplicant-basic \
    wpa-supplicant-mini \
    wpa-supplicant-mbedtls \
    wpa-supplicant-openssl \
    wpa-supplicant-wolfssl \
    wpa-supplicant-p2p \
    wpa-supplicant-mesh-openssl \
    wpa-supplicant-mesh-wolfssl \
    wpa-cli \
    eapol-test \
    eapol-test-openssl \
    eapol-test-wolfssl \
    wireless-regdb
  do
    disable_package "$pkg"
  done

# 关闭当前网络不使用的 NSS 模块
for mod in \
  nss-eip-firmware \
  kmod-qca-nss-crypto \
  kmod-qca-nss-drv-gre \
  kmod-qca-nss-drv-eogremgr \
  kmod-qca-nss-drv-map-t \
  kmod-qca-nss-drv-vxlanmgr \
  kmod-qca-nss-drv-wifi-meshmgr \
  kmod-qca-nss-drv-pptp \
  kmod-qca-nss-drv-l2tpv2 \
  kmod-qca-nss-drv-tun6rd \
  kmod-qca-nss-drv-tunipip6 \
  kmod-qca-nss-drv-igs \
  kmod-qca-nss-drv-lag-mgr \
  kmod-qca-nss-drv-mirror \
  kmod-qca-nss-drv-qdisc
do
  disable_package "$mod"
done

  echo "===== Wireless packages disabled ====="
  echo "===== Unnecessary NSS tunnel modules disabled ====="
  echo "===== Core NSS + ECM + TProxy kept ====="

else
  echo "ERROR: .config not found"
  exit 1
fi
