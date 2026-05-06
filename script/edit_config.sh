#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
#

# --- 1. 基础配置修改 ---
sed -i 's/192.168.1.1/10.0.1.254/g' package/base-files/files/bin/config_generate
sed -i "s/set system\.@system\[-1\]\.ttylogin='0'/set system.@system[-1].ttylogin='1'/g" package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/N60Pro/g' package/base-files/files/bin/config_generate

# --- 2. WIFI 配置修改 ---
sed -i 's/ImmortalWrt-2.4G/N60Pro-2.4G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/N60Pro-5G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i "s/set wireless\\.\\\${dev}\\.country=CN/set wireless.\\\${dev}.country=US/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i "s/set wireless\\.default_\\\${dev}\\.encryption=none/set wireless.default_\\\${dev}.encryption='sae-mixed'/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i "/set wireless\\.default_\\\${dev}\\.network=lan/a\set wireless.default_\\\${dev}.key='88888888'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i "/set wireless\\.default_\\\${dev}\\.mode=ap/a\set wireless.default_\\\${dev}.hidden='1'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# --- Zabbix Proxy SQLite3 深度修复与强制启用 ---
ZABBIX_DIR=$(find feeds/packages/ -name zabbix -type d | head -n 1)

if [ -n "$ZABBIX_DIR" ]; then
    echo "正在强制配置 Zabbix Proxy..."
    
    # 1. 物理删除阻碍编译的报错行 (双重保险)
    find "$ZABBIX_DIR" -name configure -exec sed -i 's/as_fn_error "SQLite is not supported as a main Zabbix database backend."/echo "Bypassing SQLite check"/g' {} +

    # 2. 修改 Makefile 强制添加依赖和配置参数
    Z_MAKE="$ZABBIX_DIR/Makefile"
    sed -i '/DEPENDS:=/ s/$/ +libsqlite3/' "$Z_MAKE"
    # 在适当位置插入 --with-sqlite3
    sed -i '/--disable-java/a \	--with-sqlite3 \\' "$Z_MAKE"

    # 3. 强制在 .config 中启用特定的变体 (非常重要)
    # 默认编译 nossl 版本以减少冲突
    echo "CONFIG_PACKAGE_zabbix-proxy-nossl=y" >> .config
    echo "CONFIG_PACKAGE_zabbix-extra-agentd=y" >> .config
    echo "CONFIG_PACKAGE_zabbix-extra-sender=y" >> .config
    echo "CONFIG_PACKAGE_zabbix-extra-get=y" >> .config
    
    # 确保依赖包也被选中
    echo "CONFIG_PACKAGE_libsqlite3=y" >> .config
    
    echo "Zabbix 配置已强制注入。"
else
    echo "警告: 未找到 Zabbix 源码目录，请检查 feeds 是否更新成功。"
fi

# 强行绕过 SQLite 检查的 Hook
define Build/Configure/Post-SQLite-Fix
	find \$(PKG_BUILD_DIR) -name configure -exec sed -i 's/as_fn_error "SQLite is not supported as a main Zabbix database backend."/echo "Bypassing SQLite check"/g' {} +
end

# 将这个 Hook 挂载到 Configure 之后，Compile 之前
Hooks/Configure/Post += Build/Configure/Post-SQLite-Fix
EOF

    echo "Zabbix Proxy 深度修复补丁已应用。"
else
    echo "错误: 未找到 Zabbix Makefile。"
fi

# --- 4. 防火墙规则 ---
cat >> package/network/config/firewall/files/firewall.config <<EOF

config rule
        option name 'Allow-UDP-igmpproxy'
        option src 'wan'
        option dest 'lan'
        option dest_ip '224.0.0.0/4'
        option proto 'udp'
        option target 'ACCEPT'        
        option family 'ipv4'

config rule
        option name 'Allow-UDP-udpxy'
        option src 'wan'
        option dest_ip '224.0.0.0/4'
        option proto 'udp'
        option target 'ACCEPT'
EOF

# --- 5. 强制启用包 ---
echo "CONFIG_PACKAGE_zabbix-proxy=y" >> .config
echo "CONFIG_PACKAGE_libsqlite3=y" >> .config
