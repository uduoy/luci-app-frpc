include $(TOPDIR)/rules.mk

PKG_VERSION:=20250610
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for Frpc
LUCI_DEPENDS:=+libc
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-frpc

define Package/$(PKG_NAME)/conffiles
/etc/config/frpc
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
if [ -f /etc/config/frpc ] ; then
  echo "备份旧 uci 配置文件 /etc/config/frpc 到 /etc/config/frpc.old"
  /etc/init.d/frpc stop 2>/dev/null
  mv -f /etc/config/frpc /etc/config/frpc.old
fi
exit 0
endef

# define Package/$(PKG_NAME)/postinst
# endef

# $(eval $(call BuildPackage,$(PKG_NAME)))

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
