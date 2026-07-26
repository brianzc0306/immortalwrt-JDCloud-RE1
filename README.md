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
- 网络优化：BBR、NSS/ECM、动态 Conntrack 上限与 TProxy 兼容策略

> RE-CS-07 本身不提供 Wi-Fi。本仓库会在构建时禁用无线用户态组件和明确不需要的 NSS 隧道模块。

## 开始构建

1. 打开仓库的 **Actions** 页面。
2. 选择 **immortalwrt-nikki**。
3. 点击 **Run workflow**。
4. 在 **Build variant** 中选择构建类型：
   - `stable`：现有稳定版，不包含 OAF。
   - `oaf-test`：加入 OpenAppFilter 的测试版。
5. 构建完成后，从对应 Release 或 Actions Artifact 下载固件。

同一分支、同一构建类型同时只运行一个构建。新构建启动时，会自动取消同类型仍在运行的旧构建，避免并发发布冲突。

## OAF 测试版

`oaf-test` 使用与固件完全相同的内核源码编译 `kmod-oaf`、`appfilter` 和 `luci-app-oaf`，不会安装来源不匹配的预编译内核模块。OAF 源码固定到提交 `a189ad85e8fb461318533941963f0e2975274a19`，该版本包含《梦幻西游》（应用 ID `2006`）识别规则和 Linux 6.18 所需的内核接口适配。

- 测试版作为 GitHub **Pre-release** 发布，标签以 `immortalwrt-oaf-test-` 开头，避免与稳定版混淆。
- 稳定版和测试版分别保留最近 3 个 Release，测试构建不会挤掉稳定版下载。
- OAF 已安装但默认关闭，不会自动禁止任何设备或应用。
- 默认继续保留 NSS/ECM，并保持软件及硬件 Flow Offloading 关闭。
- 首次测试时，先在 DHCP 中为目标设备绑定固定地址，并在 Nikki 中让该设备直连，避免代理流量绕过 OAF 的识别路径。
- 打开 LuCI 的 **服务 → App Filter**，只选择目标设备和《梦幻西游》，确认识别记录正常后再开启拦截。
- 如果能够看到设备但始终识别不到游戏流量，可在 OAF 高级设置中临时停用硬件加速后复测；这会影响全局 NSS/ECM 加速，只应作为排查步骤。

OAF 属于 DPI 特征识别，游戏更新、加密协议或代理路径变化都可能影响命中率，因此本测试版不替代按设备完全断网规则。刷写前请备份配置，建议首次测试不保留旧配置，测试完成后再决定是否合入稳定版。

## RE-CS-07 运行策略

- Conntrack 默认上限为 `131072`；实际连接数达到该值的 75% 时，本次开机自动提升到 `262144`，重启后重新从低档观察，避免长期无条件放大连接表。
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
- `source-versions.txt`：ImmortalWrt、Lucky、Nikki，以及测试版 OAF 的源码提交
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
- [destan19/OpenAppFilter](https://github.com/destan19/OpenAppFilter)

## 梦幻西游拦截测试

`oaf-test` 固件额外提供 **服务 → App Filter → 梦幻西游拦截（测试）** 页面。该功能默认关闭，只对页面中填写的固定 IPv4 地址生效；保存并应用后会立即重载独立的 nftables 规则。它不会停止 Nikki，也不会修改 HNAT、ECM 或 Flow Offloading 设置。启用后应彻底退出并重新启动游戏，使新连接经过拦截规则。

规则来自 RE-CS-07 实机抓包验证；验证时 Nikki、HNAT 和 ECM 均保持运行，适用于当前观察到的《梦幻西游》服务器线路。服务器地址可能变化，且同一地址可能承载其他网易服务，因此该功能保持测试性质，不会加入稳定版，也不会默认启用。SSH 可用以下命令检查命中计数或立即关闭：

```sh
nft list chain inet mhxy_block forward
uci set mhxy_block.main.enabled='0'
uci commit mhxy_block
/etc/init.d/mhxy-block restart
```

## License

[MIT](LICENSE)
