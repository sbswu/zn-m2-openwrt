# ZN-M2 / CMIOT-AX18 OpenWrt

无 wifi，无 USB，弱电箱专用。推荐内存 512M 以上，内核版本 4.4.60。

- uboot 刷机用 .ubi 文件
- OpenWrt 系统升级用 .bin 文件

## 配置

- uboot 控制台地址：`192.168.1.1`
- 路由器控制台地址：`192.168.10.1`
- 路由器默认密码：`password`

## 插件

- [gecoosac](https://github.com/lwb1978/openwrt-gecoosac)(已集成)
- [OpenClash](https://github.com/vernesong/OpenClash/releases/tag/v0.46.137)(**本仓库已内置**：含 ruby 依赖 + aarch64 meta 内核，刷完直接能用，旁路由配置见 [README-OpenClash.md](./README-OpenClash.md))
- [luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon/releases/tag/v1.8.4)(推荐安装)

## 重刷固件/救砖

1、长按 `reset` 按钮并开机，十秒左右路由器进入 uboot 模式。
2、将 PC 或其他终端设置为 `192.168.1.x` 网段的 IP 后，通过网线连接路由器，访问 `192.168.1.1` 进入 uboot 控制台。
3、上传后缀为 `.ubi` 的固件文件后等待路由器重启即可。

## 参考

- https://anclark.github.io/2023/05/28/OpenWRT/OpenWRT_ZN-M2/
