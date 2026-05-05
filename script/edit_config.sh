#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# --- 1. 基础配置修改 ---
# 修改默认IP
sed -i 's/192.168.1.1/10.0.1.254/g' package/base-files/files/bin/config_generate

# 添加TTL密码认证
sed -i "s/set system\.@system\[-1\]\.ttylogin='0'/set system.@system[-1].ttylogin='1'/g" package/base-files/files/bin/config_generate

# 修改主机名
sed -i 's/ImmortalWrt/N60Pro/g' package/base-files/files/bin/config_generate

# --- 2. WIFI 配置修改 ---
# 修改 SSID
sed -i 's/ImmortalWrt-2.4G/N60Pro-2.4G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/N60Pro-5G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-6G/N60Pro-6G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 替换国家代码
sed -i "s/set wireless\\.\\\${dev}\\.country=CN/set wireless.\\\${dev}.country=US/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 调整WIFI加密方式
sed -i "s/set wireless\\.default_\\\${dev}\\.encryption=none/set wireless.default_\\\${dev}.encryption='sae-mixed'/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# WIFI添加密码 (已清理多余空格)
sed -i "/set wireless\\.default_\\\${dev}\\.network=lan/a\set wireless.default_\\\${dev}.key='88888888'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 隐藏WIFI (已清理多余空格)
sed -i "/set wireless\\.default_\\\${dev}\\.mode=ap/a\set wireless.default_\\\${dev}.hidden='1'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# --- 3. Zabbix Proxy SQLite3 核心修复逻辑 ---
# 寻找 Zabbix 目录
ZABBIX_MAKE=$(find feeds/packages/ -name Makefile | grep "admin/zabbix/Makefile")

if [ -n "$ZABBIX_MAKE" ]; then
    echo "发现 Zabbix Makefile: $ZABBIX_MAKE"
    ZABBIX_DIR=$(dirname "$ZABBIX_MAKE")

    # A. 修改 Makefile：强制注入依赖和编译参数
    sed -i '/DEPENDS:=/ s/$/ +libsqlite3/' "$ZABBIX_MAKE"
    sed -i '/CONFIG_ZABBIX_MYSQL/d' "$ZABBIX_MAKE"
    sed -i '/CONFIG_ZABBIX_POSTGRESQL/d' "$ZABBIX_MAKE"
    # 在 --disable-java 后强制插入 --with-sqlite3
    sed -i '/--disable-java/a \	--with-sqlite3 \\' "$ZABBIX_MAKE"

    # B. 关键修复：绕过 configure 脚本对 SQLite 的检查
    # 我们直接修改源码目录下的 configure 脚本内容，删除报错退出逻辑
    # 这个 sed 命令会把报错提示替换为 echo 提示，从而防止退出
    echo "正在绕过 Zabbix SQLite 检查限制..."
    find "$ZABBIX_DIR" -name "configure" | xargs -r sed -i 's/as_fn_error "SQLite is not supported as a main Zabbix database backend."/echo "Bypassing SQLite check"/g'
    
    echo "Zabbix Proxy 已强制配置为 SQLite3。"
else
    echo "警告: 未找到 Zabbix Makefile。"
fi

# --- 4. 防火墙规则添加 ---
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

# --- 5. 强制开启编译选项 ---
# 确保即使 .config 没选，也会强制编译这两个包
echo "CONFIG_PACKAGE_zabbix-proxy=y" >> .config
echo "CONFIG_PACKAGE_libsqlite3=y" >> .config
