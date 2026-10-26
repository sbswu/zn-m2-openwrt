#!/bin/bash
#
# diy-part3.sh —— 在 .config 就位后、make defconfig 之前执行
# 工作目录：openwrt 源码根目录
#
set -e

CORE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
CORE_URL_MIRROR="https://cdn.jsdelivr.net/gh/vernesong/OpenClash@core/master/meta/clash-linux-arm64.tar.gz"
MMDB_URL="https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb"

echo "==> [diy3] 修正 uci-defaults 脚本执行权限"
# Windows 上 git 常把新文件存成 644，而 OpenWrt 只执行带 x 位的
# /etc/uci-defaults/*，权限丢了等于这些默认值全部不生效（旁路由兼容模式
# 官方默认是 0，丢了就起不来）。
if [ -d files/etc/uci-defaults ]; then
	chmod 0755 files/etc/uci-defaults/* 2>/dev/null || true
	for f in files/etc/uci-defaults/*; do
		[ -x "$f" ] || { echo "!! $f 不可执行"; exit 1; }
		echo "    $(ls -l "$f" | awk '{print $1, $NF}')"
	done
fi

echo "==> [diy3] 强制使用 OpenClash feed 的 v0.46.137"
# install -a 之后仍可能残留 luci feed 的 0.45.152（索引/软链），这里直接以
# feeds/openclash 的源码覆盖为本地包，保证最终编进去的只有 0.46.137。
OC_SRC="feeds/openclash/luci-app-openclash"
[ -f "$OC_SRC/Makefile" ] || { echo "!! 找不到 $OC_SRC"; exit 1; }
rm -rf package/feeds/luci/luci-app-openclash \
       package/feeds/openclash/luci-app-openclash \
       package/luci-app-openclash
cp -r "$OC_SRC" package/luci-app-openclash
OC_VER="$(sed -n 's/^PKG_VERSION:=//p' package/luci-app-openclash/Makefile | head -n1)"
OC_REL="$(sed -n 's/^PKG_RELEASE:=//p' package/luci-app-openclash/Makefile | head -n1)"
echo "    版本: $OC_VER${OC_REL:+-$OC_REL}"
[ "$OC_VER" = "0.46.137" ] || { echo "!! 版本不是 0.46.137"; exit 1; }

echo "==> [diy3] 默认 LAN 地址改为 192.168.10.1"
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

echo "==> [diy3] 预置 mihomo(Meta) arm64 内核到 /etc/openclash/core/clash_meta"
mkdir -p files/etc/openclash/core

ok=0
for url in "$CORE_URL" "$CORE_URL_MIRROR"; do
	for i in 1 2 3; do
		echo "    下载 $url (第 $i 次)"
		if curl -fsSL --retry 2 --connect-timeout 20 -m 300 "$url" -o /tmp/clash-meta.tar.gz; then
			ok=1
			break 2
		fi
		sleep 5
	done
done
[ "$ok" = "1" ] || { echo "!! 内核下载失败"; exit 1; }
[ -s /tmp/clash-meta.tar.gz ] || { echo "!! 内核文件为空"; exit 1; }

rm -rf /tmp/oc-core && mkdir -p /tmp/oc-core
tar -xzf /tmp/clash-meta.tar.gz -C /tmp/oc-core
CORE_BIN="$(find /tmp/oc-core -type f | head -n1)"
[ -n "$CORE_BIN" ] || { echo "!! 内核解包失败"; exit 1; }
install -m 0755 "$CORE_BIN" files/etc/openclash/core/clash_meta
echo -n "    内核大小: "; du -h files/etc/openclash/core/clash_meta | awk '{print $1}'
file files/etc/openclash/core/clash_meta || true

echo "==> [diy3] 预置 Country.mmdb（国内 IP 段库，约 260KB）"
if curl -fsSL --retry 2 --connect-timeout 20 -m 120 "$MMDB_URL" -o files/etc/openclash/Country.mmdb; then
	echo -n "    mmdb 大小: "; du -h files/etc/openclash/Country.mmdb | awk '{print $1}'
else
	echo "    跳过（首次启动 OpenClash 时会自动下载）"
fi

echo "==> [diy3] 完成"
