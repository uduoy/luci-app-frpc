include $(TOPDIR)/rules.mk

PKG_VERSION:=20250611
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for Frps
LUCI_DEPENDS:=+libc
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-frps

define Package/$(PKG_NAME)/conffiles
/etc/config/frps
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
if [ -f /etc/config/frps ] ; then
  [ -n "$(uci -q show frps.main)" ] && exit 0
  echo "备份旧 uci 配置文件 /etc/config/frps 到 /etc/config/frps.old"
  /etc/init.d/frps stop 2>/dev/null
  mv -f /etc/config/frps /etc/config/frps.old
fi
exit 0
endef

# define Package/$(PKG_NAME)/postinst
# endef

# $(eval $(call BuildPackage,$(PKG_NAME)))

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
