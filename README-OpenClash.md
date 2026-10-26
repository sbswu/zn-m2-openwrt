# ZN-M2 旁路由固件（内置 OpenClash）编译说明

> 基于 [CarlisleChan/zn-m2-openwrt](https://github.com/CarlisleChan/zn-m2-openwrt) 改的。
> 目标：**无 WiFi、无 USB、只有 LAN 的旁路由**，开机就有 OpenClash，内核已经预置好，不联网也能跑。

---

## 一、改了哪些东西

| 文件 | 改动 |
| --- | --- |
| `feeds.conf.default` | 增加 OpenClash feed，锁定 `v0.46.137`（作者推荐版，Lua 版 LuCI 兼容最好） |
| `config/zn-m2.config` | 加入 `luci-app-openclash` 及全部依赖：`ruby`、`ruby-yaml`、`unzip`、`ca-bundle`、`iptables-mod-tproxy`、`iptables-mod-extra`、`kmod-ipt-ipset`、`dnsmasq_full_ipset` |
| `scripts/zn-m2/diy-part2.sh` | 从 `ipq60xx` 镜像定义里删掉 `kmod-usb3`/`kmod-usb-phy-msm`（不要 USB），并检查 OpenClash feed 是否拉取成功 |
| `scripts/zn-m2/diy-part3.sh` | 默认 LAN 改 `192.168.10.1`；**把 mihomo(Meta) arm64 内核预先塞进 `/etc/openclash/core/clash_meta`**，顺带塞 `Country.mmdb` |
| `files/root/bypass-setup.sh` | 旁路由一键配置脚本（SSH 里 `sh /root/bypass-setup.sh`） |
| `files/etc/uci-defaults/90-openclash-bypass` | 首次启动自动把 OpenClash 设成 `Fake-IP + 旁路由兼容模式` |
| `.github/workflows/zn-m2.yml` | 编译前后各加一道校验：`.config` 里缺任何依赖、镜像里没有 `luci-app-openclash`，直接红叉报错，**不会给你一个"看起来成功其实没插件"的固件** |

### 三个关键点（这是别人抄作业最容易翻车的地方）

1. **OpenClash 插件包本身不带内核**。
   官方 ipk 里只有 LuCI 页面和 shell 脚本，`/etc/openclash/core/clash_meta` 是空的，首次启用时会去 GitHub 下内核——国内大概率下不动，表现就是"启用失败/内核未安装"。所以这里在编译期就把 aarch64 的 meta 内核打进镜像。
2. **内核架构必须是 arm64**。
   ZN-M2 是 IPQ6000（Cortex-A53 四核），要 `linux-arm64` 的版本，用 mips 的必崩。
3. **这套源码是 21.02 风格 + firewall3(iptables)**，不是 fw4/nftables。
   所以依赖要选 `iptables-mod-tproxy` / `kmod-ipt-ipset` / `dnsmasq_full_ipset`，不能选 `kmod-nft-tproxy`。

---

## 二、出固件（GitHub Actions，约 60–90 分钟）

我这边没有你的 GitHub 权限，所以最后"点一下编译"需要你来触发。整个过程 5 分钟搞定：

### 步骤 1：Fork 仓库

浏览器打开 <https://github.com/CarlisleChan/zn-m2-openwrt>，右上角 **Fork** → 得到
`https://github.com/<你的用户名>/zn-m2-openwrt`

### 步骤 2：把我改好的这套推上去

本机已经有改好的完整仓库（路径：`C:\Users\WIN10_PVE\WorkBuddy\2026-10-26-14-40-36\src-znm2`），直接：

```bash
cd C:/Users/WIN10_PVE/WorkBuddy/2026-10-26-14-40-36/src-znm2
git remote set-url origin https://github.com/<你的用户名>/zn-m2-openwrt.git
git push origin dev
```

> 推送时用户名填 GitHub 用户名，密码位置填 **Personal Access Token**（Settings → Developer settings → Personal access tokens → 勾 `repo`）。
> 如果提示 `non-fast-forward`，就 `git push -f origin dev`（覆盖你自己 fork 的 dev 分支，安全）。

**不想用命令行**的话：在你的 fork 里进 `config/zn-m2.config`、`feeds.conf.default`、`scripts/zn-m2/diy-part2.sh`、`scripts/zn-m2/diy-part3.sh` 四个文件，点铅笔图标，把本仓库同名文件内容整段粘进去；再 `Add file → Upload files` 把 `files/` 整个目录拖进去。

### 步骤 3：跑编译

1. 你的 fork 页 → **Actions** 标签，第一次会让你点 "I understand my workflows, go ahead and enable them"
2. 左边选 **zn-m2** → 右边 **Run workflow** → 分支选 `dev` → **Run workflow**
3. 等它跑完（60–90 分钟，日志里会打印 `OK CONFIG_PACKAGE_luci-app-openclash` 之类的校验行）
4. 跑完去 **Releases**（不是 Artifacts，Release 里也有）下载：
   - `*nand-sysupgrade.bin` —— OpenWrt 系统内升级用
   - `*nand-factory.ubi` —— **Uboot 刷机用**（新机/救砖用这个）

> 编译中途如果红叉：点进失败的步骤，把最后 50 行日志发我，我针对改。

---

## 三、刷机

### 第一次刷（Uboot 方式，推荐）

1. 长按 `reset` 键 **不放**，插电，等 10 秒左右，路由器进入 Uboot
2. 电脑网卡设成 `192.168.1.x`（如 `192.168.1.100`），网线接**路由器的 LAN 口**
3. 浏览器打开 `192.168.1.1`，选 `.ubi` 文件上传，等它自己重启（3–5 分钟，别断电）
4. 起来后访问 **`192.168.10.1`**，默认密码 `password`

### 以后升级（已经是 OpenWrt 了）

系统 → 备份/升级 → 刷 `.bin`，**不要**保留配置（跨大版本时）。

> ⚠️ 刷机有变砖风险，虽然这个机器有 Uboot 兜底。别用不稳的电源，别在刷写时断电。

---

## 四、配成旁路由

接线：**主路由 LAN 口 → ZN-M2 的 LAN 口**（不要插 WAN 口，我们不用它）。

SSH 登录 `192.168.10.1` 后执行：

```sh
sh /root/bypass-setup.sh
```

按提示填**主路由 IP**（比如 `192.168.1.1`）即可，脚本会做三件事：

- 给旁路由配上默认网关和 DNS = 主路由（这样旁路由自己能上网、能更新订阅）
- 关掉旁路由的 DHCP（地址继续由主路由发，避免两个 DHCP 打架）
- 关掉不用的 WAN/WAN6（避免抢默认路由）

### 然后二选一让设备走旁路由

**A. 全局生效（推荐）**
进主路由的管理页 → DHCP 设置 → 把「默认网关」和「DNS 服务器」都改成 `192.168.10.1` → 保存 → 设备重新连一下 WiFi。

**B. 只让部分设备走**
不动主路由，在要翻墙的那台设备上手动设：IP 随便（同网段）、网关 `192.168.10.1`、DNS `192.168.10.1`。

---

## 五、OpenClash 设置（关键几步）

LuCI → **服务 → OpenClash**：

1. **全局设置 → 运行模式**：`Fake-IP`（镜像里已经预置好了，这也是 OpenClash 官方默认值）
2. **全局设置 → 旁路由兼容模式**：勾选（也已预置）
3. **配置文件订阅** → 添加订阅链接 → 保存 → 点「更新」
4. 回首页 → **启用**，等 30 秒左右状态变成「运行中」
5. 点「控制面板」或访问 `http://192.168.10.1:9090/ui`，能看到节点和延迟就成功了

### 自查三条命令

```sh
# 1. 内核在不在、能不能跑
/etc/openclash/core/clash_meta -v

# 2. 进程在不在
pidof clash

# 3. 透明代理规则有没有挂上
iptables -t nat -L -n | grep -i clash
```

DNS 建议：客户端只用旁路由做 DNS（方案 A/B 都已经保证）。如果你在主路由上还配了别的 DNS（比如运营商 DNS、DoH），`GEOIP,CN` 相关规则会不准。

### Fake-IP 的两个正常现象（别当故障）

- `ping 域名` 会显示 `198.18.0.x` 且不通 —— ICMP 不经过 clash，这是正常的。用 `curl -I https://www.google.com` 验证。
- 客户端刚连上时前几个请求偶尔慢一下 —— 在等 clash 后台补解析真实 IP，之后就稳定了。

这两种情况下，如果你确实希望某个设备或域名拿到真实 IP，可以把设备 IP 加进「访问控制 → 不走代理的 IP」，或在「全局设置 → DNS → Fake-IP-Filter」里加域名。

---

## 六、常见问题

**Q：编译报 `Package luci-app-openclash is missing dependencies for ... ruby-yaml`**
→ feeds 没更新成功。本地重新跑 `./scripts/feeds update -a && ./scripts/feeds install -a`，或看 Action 日志里 `Update feeds` 那一步。

**Q：启用 OpenClash 提示"内核未安装/下载失败"**
→ 说明镜像里的内核丢了。检查 Action 日志 `diy-part3.sh` 那步有没有 `内核大小: 13M` 的输出；没有就是下载失败，重跑一次。

**Q：刷完进不去 `192.168.10.1`**
→ 电脑网卡设成 `192.168.10.x` 静态试试；还不行就 Uboot 重刷（长按 reset 插电）。

**Q：固件会不会太大？**
→ ZN-M2 是 128MB NAND。这套加了 OpenClash（约 10MB）+ ruby 依赖（约 8MB）+ 内核 13MB，总量大概 55–65MB，够用。要是你想再省，可以把 `config/zn-m2.config` 里的 `PACKAGE_luci-app-sqm`/`luci-app-upnp`/`gecoosac` 去掉。

**Q：还能不能加别的插件？**
→ 在 `config/zn-m2.config` 里加 `CONFIG_PACKAGE_xxx=y` 就行，注意别把 `luci-app-openclash` 和它那几个依赖删掉。

---

## 七、想改回官方原版配置

这个仓库本来就是原版，只动了上面列的 7 个文件。把 `config/`、`feeds.conf.default`、`scripts/`、`files/` 换回原样即可。
