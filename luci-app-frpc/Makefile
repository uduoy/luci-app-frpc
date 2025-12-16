include $(TOPDIR)/rules.mk

PKG_VERSION:=20251216
PKG_RELEASE:=4
PKG_NAME:=luci-app-frpc

LUCI_TITLE:=LuCI support for Frpc
LUCI_DEPENDS:=+libc
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/preinst
#!/bin/sh
if [ -f /etc/config/frpc ] ; then
  uci show frpc.main >/dev/null 2>&1 && exit 0
  echo "备份旧 uci 配置文件 /etc/config/frpc 到 /etc/config/frpc.old"
  /etc/init.d/frpc stop 2>/dev/null
  mv -f /etc/config/frpc /etc/config/frpc.old
fi
exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
chmod 0755 /etc/init.d/frpc
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
