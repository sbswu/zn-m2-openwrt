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

# luci feed 自带 luci-app-openclash 0.45.152，feeds install 时先到先得会把
# 我们指定的 v0.46.137 顶掉。这里在 install 之前把旧包连索引项一起摘掉。
echo "==> [diy2] 屏蔽 luci feed 自带的旧版 OpenClash"
OLD_OC="feeds/luci/applications/luci-app-openclash"
if [ -d "$OLD_OC" ]; then
	OLD_VER="$(sed -n 's/^PKG_VERSION:=//p' "$OLD_OC/Makefile" 2>/dev/null | head -n1)"
	echo "    发现旧版 ${OLD_VER:-未知}，移除"
	rm -rf "$OLD_OC"
	[ -f feeds/luci/index ] && sed -i '/^luci-app-openclash:/d' feeds/luci/index
fi
NEW_VER="$(sed -n 's/^PKG_VERSION:=//p' feeds/openclash/luci-app-openclash/Makefile 2>/dev/null | head -n1)"
case "$NEW_VER" in
	0.46.*) echo "    将使用 OpenClash feed 版本 $NEW_VER" ;;
	*) echo "!! OpenClash feed 版本异常: ${NEW_VER:-读取失败}"; exit 1 ;;
esac
