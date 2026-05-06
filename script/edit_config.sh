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

# --- 3. Zabbix Proxy SQLite3 深度修复 ---
ZABBIX_DIR=$(find feeds/packages/ -name zabbix -type d | head -n 1)

if [ -n "$ZABBIX_DIR" ]; then
    echo "正在为 Zabbix Proxy 注入自动修复挂钩..."
    Z_MAKE="$ZABBIX_DIR/Makefile"

    # A. 修改 Makefile 依赖
    sed -i '/DEPENDS:=/ s/$/ +libsqlite3/' "$Z_MAKE"
    
    # B. 在配置参数中插入 SQLite3 支持
    sed -i '/--disable-java/a \	--with-sqlite3 \\' "$Z_MAKE"

    # C. 将 Makefile 语法写入 Makefile (使用反斜杠转义以防 Shell 解析)
    cat >> "$Z_MAKE" <<EOF

# 自动绕过 SQLite 限制的 Hook
define Build/Configure/Post-SQLite-Fix
	find \$(PKG_BUILD_DIR) -name configure -exec sed -i 's/as_fn_error "SQLite is not supported as a main Zabbix database backend."/echo "Bypassing SQLite check"/g' {} +
end

Hooks/Configure/Post += Build/Configure/Post-SQLite-Fix
EOF

    # D. 强制选中包变体
    echo "CONFIG_PACKAGE_zabbix-proxy-nossl=y" >> .config
    echo "CONFIG_PACKAGE_zabbix-extra-agentd=y" >> .config
    echo "CONFIG_PACKAGE_zabbix-extra-sender=y" >> .config
    echo "CONFIG_PACKAGE_zabbix-extra-get=y" >> .config
    echo "CONFIG_PACKAGE_libsqlite3=y" >> .config

    echo "Zabbix 补丁注入完成。"
else
    echo "错误: 未找到 Zabbix 源码目录。"
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
