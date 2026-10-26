#!/bin/sh
#
# ZN-M2 旁路由一键配置脚本
# 用法（SSH 登录路由器后执行）：
#     sh /root/bypass-setup.sh
#
# 作用：
#   1. 给旁路由配好「网关 / DNS 指向上级主路由」
#   2. 关掉旁路由自己的 DHCP（让主路由继续发地址，避免冲突）
#   3. 关掉不用的 WAN 口（旁路由只走 LAN 口到主路由）
#
# 回滚：把本脚本里改过的项用 uci 改回去即可，或直接恢复出厂。
#

set -e

echo "=================================================="
echo "        ZN-M2 旁路由配置向导（OpenClash 版）"
echo "=================================================="
echo

CUR_IP=$(uci -q get network.lan.ipaddr || echo 192.168.10.1)
echo "当前旁路由地址：$CUR_IP"
echo

printf "上级主路由 IP（比如 192.168.1.1）："
read -r MAIN
if [ -z "$MAIN" ]; then
	echo "不能为空，退出。"
	exit 1
fi
if ! echo "$MAIN" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
	echo "IP 格式不对：$MAIN"
	exit 1
fi

printf "旁路由自己的 IP（回车沿用 $CUR_IP）："
read -r SELF
[ -z "$SELF" ] && SELF="$CUR_IP"

printf "旁路由子网掩码（回车默认 255.255.255.0）："
read -r MASK
[ -z "$MASK" ] && MASK="255.255.255.0"

echo
echo "即将写入："
echo "  旁路由 IP : $SELF / $MASK"
echo "  默认网关 : $MAIN"
echo "  DNS      : $MAIN"
echo "  LAN DHCP  : 关闭（由主路由分配）"
echo "  WAN 口    : 关闭（旁路由不用 WAN）"
echo
printf "确认执行？(y/N) "
read -r YN
case "$YN" in
	y|Y) ;;
	*) echo "已取消。"; exit 0 ;;
esac

# 1) LAN 地址 + 网关 + DNS
uci -q set network.lan.ipaddr="$SELF"
uci -q set network.lan.netmask="$MASK"
uci -q set network.lan.gateway="$MAIN"
uci -q set network.lan.dns="$MAIN"
uci -q set network.lan.delegate="0"

# 2) 关掉 LAN 上的 DHCP 服务（含 IPv6 RA/DHCPv6）
uci -q set dhcp.lan.ignore="1"
uci -q set dhcp.lan.dhcpv6="disabled"
uci -q set dhcp.lan.ra="disabled"
uci -q commit dhcp

# 3) 关掉 WAN / WAN6（旁路由用不到，避免抢默认路由）
uci -q set network.wan.proto="none"
uci -q set network.wan6.proto="none"
uci -q commit network

# 4) 让 dnsmasq 只服务本机、不做上游解析缓存给外部（OpenClash 接管 DNS）
uci -q set dhcp.@dnsmasq[0].localservice="1"
uci -q set dhcp.@dnsmasq[0].domainneeded="0"
uci -q set dhcp.@dnsmasq[0].boguspriv="0"
uci -q set dhcp.@dnsmasq[0].rebindprotection="0"
uci -q commit dhcp

echo
echo "正在应用配置……"
/etc/init.d/network reload >/dev/null 2>&1 || true
/etc/init.d/dnsmasq restart >/dev/null 2>&1 || true
sleep 3

echo
echo "=================================================="
echo " 配置完成，请用新地址访问：http://$SELF"
echo "=================================================="
echo
echo "接下来在 LuCI 里做两件事："
echo "  1) 服务 → OpenClash → 全局设置："
echo "     - 运行模式：Redir-Host（兼容）"
echo "     - 旁路由兼容模式：勾选"
echo "     - DNS：保持默认（本地 DNS 劫持 7874）"
echo "  2) 服务 → OpenClash → 配置文件订阅："
echo "     添加你的机场订阅 → 保存 → 应用"
echo "  3) 回 OpenClash 首页点【启用】"
echo
echo "然后把主路由 DHCP 的「网关」和「DNS」都改成 $SELF，"
echo "或者只在需要翻墙的设备上手动把网关/DNS 指到 $SELF。"
echo
