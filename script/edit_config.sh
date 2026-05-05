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

# --- 3. Zabbix Proxy SQLite3 核心修复 (增强版) ---
ZABBIX_MAKE=$(find feeds/packages/ -name Makefile | grep "admin/zabbix/Makefile")

if [ -n "$ZABBIX_MAKE" ]; then
    echo "正在深度修复 Zabbix SQLite3 限制..."
    
    # A. 修改 Makefile，增加 --with-sqlite3 参数并添加依赖
    sed -i '/DEPENDS:=/ s/$/ +libsqlite3/' "$ZABBIX_MAKE"
    # 在 CONFIGURE_ARGS 中强制插入 sqlite 支持
    sed -i '/--disable-java/a \	--with-sqlite3 \\' "$ZABBIX_MAKE"

    # B. 暴力破解 configure 脚本限制
    # 我们不仅修改已存在的 configure，还通过一种“钩子”方式，
    # 在 Makefile 的编译准备阶段直接把错误检查逻辑删掉
    sed -i 's/as_fn_error "SQLite is not supported as a main Zabbix database backend."/echo "Bypassing SQLite check"/g' $(find feeds/packages/ -name configure) 2>/dev/null || true

    # C. 针对 OpenWrt 编译流程的特殊补丁
    # 这一行会在编译开始前，强行搜索 build_dir 下解压出来的 configure 并修改它
    # 防止 patch 或 autoreconf 重新生成了带报错的 configure
    cat >> "$ZABBIX_MAKE" <<EOF

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
