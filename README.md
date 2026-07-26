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
- 网络优化：BBR 与适用于 2 GB 内存设备的基础参数

> RE-CS-07 本身不提供 Wi-Fi。本仓库会在构建时禁用无线用户态组件和明确不需要的 NSS 隧道模块。

## 开始构建

1. 打开仓库的 **Actions** 页面。
2. 选择 **immortalwrt-nikki**。
3. 点击 **Run workflow**。
4. 构建完成后，从对应 Release 或 Actions Artifact 下载固件。

同一分支同时只运行一个构建。新构建启动时，会自动取消仍在运行的旧构建，避免并发发布冲突。

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

`nikki.config` 只显式选择用户功能和顶层应用。其底层库、内核模块及服务由 OpenWrt 包依赖自动补齐，以降低配置维护成本。

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
| `.github/workflows/immortalwrt-nikki.yml` | 构建、校验、发布和清理流程 |

## 致谢

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
- [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)
- [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki)
- [gdy666/luci-app-lucky](https://github.com/gdy666/luci-app-lucky)

## License

[MIT](LICENSE)
