#!/bin/bash
#
# diy-part3.sh —— 在 .config 就位后、make defconfig 之前执行
# 工作目录：openwrt 源码根目录
#
set -e

CORE_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
CORE_URL_MIRROR="https://cdn.jsdelivr.net/gh/vernesong/OpenClash@core/master/meta/clash-linux-arm64.tar.gz"
MMDB_URL="https://testingcf.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb"

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
