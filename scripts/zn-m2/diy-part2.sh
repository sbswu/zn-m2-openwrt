#!/bin/bash
#
# diy-part2.sh —— 在 feeds update 之后、feeds install 之前执行
# 工作目录：openwrt 源码根目录
#
set -e

echo "==> [diy2] 去掉 zn_m2 设备的 USB 相关包（本机不用 USB）"
IMG_MK="target/linux/ipq60xx/image/Makefile"
if [ -f "$IMG_MK" ]; then
	sed -i '/^define Device\/zn_m2$/,/^endef$/ s|^\([[:space:]]*\)DEVICE_PACKAGES :=.*|\1DEVICE_PACKAGES :=|' "$IMG_MK"
	if sed -n '/^define Device\/zn_m2$/,/^endef$/p' "$IMG_MK" | grep -q 'kmod-usb3'; then
		echo "!! 未能去掉 zn_m2 的 USB 包，请检查 image/Makefile"
		exit 1
	fi
	echo "    已去掉 kmod-usb3 / kmod-usb-phy-msm"
else
	echo "!! 找不到 $IMG_MK"
	exit 1
fi

echo "==> [diy2] 检查 OpenClash 包是否已进 feeds"
if [ -d "package/feeds/openclash" ] || [ -d "feeds/openclash/luci-app-openclash" ]; then
	echo "    OK"
else
	echo "!! feeds 里没有 OpenClash，请检查 feeds.conf.default"
	exit 1
fi
