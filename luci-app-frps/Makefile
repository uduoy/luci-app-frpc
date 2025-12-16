include $(TOPDIR)/rules.mk

PKG_VERSION:=20251216
PKG_RELEASE:=4
PKG_NAME:=luci-app-frps

LUCI_TITLE:=LuCI support for Frps
LUCI_DEPENDS:=+libc
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/preinst
#!/bin/sh
if [ -f /etc/config/frps ] ; then
  uci show frps.main >/dev/null 2>&1 && exit 0
  echo "备份旧 uci 配置文件 /etc/config/frps 到 /etc/config/frps.old"
  /etc/init.d/frps stop 2>/dev/null
  mv -f /etc/config/frps /etc/config/frps.old
fi
exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
chmod 0755 /etc/init.d/frps
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
