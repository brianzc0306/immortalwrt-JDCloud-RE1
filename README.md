# ImmortalWrt for JDCloud RE-CS-07

使用 GitHub Actions 为京东云无线宝 RE-CS-07（IPQ60xx）构建 ImmortalWrt 固件。

## 固件信息

- 上游源码：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)
- 构建分支：`main`
- 目标平台：`qualcommax/ipq60xx`
- 目标设备：`jdcloud_re-cs-07`
- 默认管理地址：`192.168.0.1`
- 默认界面：简体中文 LuCI + Argon 主题
- 主要插件：Nikki、Lucky、msd_lite、UPnP
- 网络优化：BBR、TCP buffer 调优、NSS/ECM、动态 Conntrack 上限与 TProxy 兼容策略

> RE-CS-07 本身不提供 Wi-Fi。本仓库会在构建时禁用无线用户态组件和明确不需要的 NSS 隧道模块。

## 开始构建

1. 打开仓库的 **Actions** 页面。
2. 选择 **immortalwrt-nikki**。
3. 点击 **Run workflow**。
4. 构建完成后，从对应 Release 或 Actions Artifact 下载固件。

同一分支同时只运行一个构建。新构建启动时，会自动取消仍在运行的旧构建，避免并发发布冲突。仅保留最近 3 个 Release。

## RE-CS-07 运行策略

- Conntrack 默认上限为 `131072`；实际连接数达到该值的 75% 时，本次开机自动提升到 `262144`，重启后重新从低档观察，避免长期无条件放大连接表。TCP established 超时从内核默认的 7440 秒收紧到 3600 秒，减少死连接白占表项；监控进程同时盯 `insert_failed`/`drop` 计数，连接表真打满丢包时会在日志中记录。
- 保留构建源默认提供的 NSS 核心与 ECM，并由构建流程确认 `kmod-qca-nss-drv`、`kmod-qca-nss-ecm` 和 Nikki 所需的 `kmod-nft-tproxy` 均已选中。
- 默认关闭防火墙软件及硬件 Flow Offloading，避免与 NSS/ECM、Nikki 的 nftables 标记和 TProxy 路径重复加速。
- Nikki 核心日志级别为 `warning`，应用日志和核心日志各以 1 MB 为清理阈值；日志位于 RAM 支撑的 `/var/log`。Lucky 使用有上限的内存日志，并关闭重复的 init 启停消息。
- 不修改 CPU governor 或频率上下限，继续使用上游动态调频和内核热管理；温度达到 80°C、90°C 或降回 75°C 以下时才记录状态变化，避免周期性刷日志。

通过 SSH 执行以下命令可查看 Conntrack、温度、CPU 动态频率、NSS/ECM 状态和 Flow Offloading 设置：

```sh
re-cs-07-status
```

高级用户可编辑 `/etc/config/re_cs_07` 调整监控间隔和阈值，然后执行 `/etc/init.d/re-cs-07-monitor restart`。

## 下载与校验

每次成功构建会发布以下辅助文件：

- `sha256sums`：所有发布文件的 SHA-256 校验值
- `config.seed`：经过 `make defconfig` 处理的最终构建配置
- `packages.manifest`：固件包含的软件包清单
- `source-versions.txt`：ImmortalWrt、Lucky 和 Nikki 的源码提交
- `release.txt`：本次构建说明

Linux/macOS 校验示例：

```bash
sha256sum -c sha256sums
```

PowerShell 校验示例：

```powershell
Get-FileHash .\固件文件名 -Algorithm SHA256
```

将输出值与 `sha256sums` 中对应文件的值进行比较。

## 自定义

- 软件包选择：编辑 [`nikki.config`](nikki.config)
- 构建后调整：编辑 [`diy-part2.sh`](diy-part2.sh)
- Actions 流程：编辑 [`.github/workflows/immortalwrt-nikki.yml`](.github/workflows/immortalwrt-nikki.yml)

`nikki.config` 主要显式选择用户功能和顶层应用；NSS、ECM 与 TProxy 作为本机关键数据路径额外固定并在构建时校验。其余底层库、内核模块及服务由 OpenWrt 包依赖自动补齐。

## 注意事项

- 固件仅面向 JDCloud RE-CS-07，请勿刷入其他型号。
- 刷写前请备份原有配置，并确认设备分区布局和升级方式。
- ImmortalWrt、Lucky 和 Nikki 默认跟随各自 `main` 分支，因此不同日期的构建可能包含不同上游版本；实际提交记录见 `source-versions.txt`。
- 修改软件包配置后，建议先检查生成的 `config.seed` 和 `packages.manifest`。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `nikki.config` | 设备目标和顶层软件包配置 |
| `diy-part2.sh` | 拉取第三方插件、设置默认地址及精简设备组件 |
| `files/` | RE-CS-07 运行时监控、状态命令和首次启动策略 |
| `.github/workflows/immortalwrt-nikki.yml` | 构建、校验、发布和清理流程 |

## 致谢

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)
- [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki)
- [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky)

## License

[MIT](LICENSE)
