#!/bin/bash
# Shell script to integrate AIC8800 driver and firmware into FriendlyWrt (NanoPi R3S)

set -e  # 发生错误时退出

echo "[INFO] Cloning AIC8800 driver repository..."
git clone --depth=1 https://github.com/goecho/aic8800_linux_drvier.git aic8800_src

# 确认目标源码目录存在（假定当前目录就是 FriendlyWrt 源码树根）
if [ ! -d "package" ]; then
    echo "[ERROR] OpenWrt source tree not found (package directory is missing)."
    exit 1
fi

echo "[INFO] Creating OpenWrt package directory for AIC8800 driver..."
# 在 package/kernel 下创建子目录存放驱动
mkdir -p package/kernel/aic8800
cp -r aic8800_src/drivers/aic8800 package/kernel/aic8800/src

# 编写 OpenWrt 包 Makefile
cat > package/kernel/aic8800/Makefile << 'EOF'
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-aic8800
PKG_RELEASE:=1

# 使用本地已克隆的源码，不从远程下载
# 定义源码目录（使用当前包目录下的src）
PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/aic8800

include $(INCLUDE_DIR)/package.mk

define KernelPackage/aic8800
  SUBMENU:=Wireless Drivers
  TITLE:=AIC8800 WiFi Driver (AICSemi)
  FILES:=$(PKG_BUILD_DIR)/aic8800_fdrv.ko
  AUTOLOAD:=$(call AutoLoad,50,aic8800_fdrv,1)
  DEPENDS:=@PCI_SUPPORT +kmod-cfg80211 +kmod-mac80211   # 根据需要选择依赖
endef

define KernelPackage/aic8800/Description
 Kernel driver for AICSemi AIC8800 802.11ax Wi-Fi chipset (supports USB/SDIO) 
endef

# 准备源码：复制预先下载的源码到构建目录
define Build/Prepare
	$(MKDIR) $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

# 使用内核构建系统编译模块
define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" M="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,aic8800))
EOF

echo "[INFO] AIC8800 package Makefile created."

# 复制固件文件到 OpenWrt 文件系统映像的对应目录
echo "[INFO] Copying AIC8800 firmware files to files/lib/firmware..."
mkdir -p files/lib/firmware
# 假设固件目录为 fw/aic8800D80，复制整个目录
cp -r aic8800_src/fw/aic8800D80/* files/lib/firmware/

# 修改 .config 以编译并内置 AIC8800 驱动
# 设置 kmod-aic8800 为y，表示将驱动模块包含进固件
if ! grep -q "^CONFIG_PACKAGE_kmod-aic8800=y" .config ; then
    echo "CONFIG_PACKAGE_kmod-aic8800=y" >> .config
fi

echo "[INFO] AIC8800 driver enabled in .config."

# 将配置更新到实际编译选项
make defconfig || make oldconfig

echo "[INFO] AIC8800 driver and firmware integration script completed successfully."
