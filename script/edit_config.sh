#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# --- 基础配置修改 ---
# 修改默认IP
sed -i 's/192.168.1.1/10.0.1.254/g' package/base-files/files/bin/config_generate

# 添加TTL密码认证
sed -i "s/set system\.@system\[-1\]\.ttylogin='0'/set system.@system[-1].ttylogin='1'/g" package/base-files/files/bin/config_generate

# 修改主机名
sed -i 's/ImmortalWrt/N60Pro/g' package/base-files/files/bin/config_generate

# --- WIFI 配置修改 ---
# 修改 SSID
sed -i 's/ImmortalWrt-2.4G/N60Pro-2.4G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-5G/N60Pro-5G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
sed -i 's/ImmortalWrt-6G/N60Pro-6G/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 替换国家代码
sed -i "s/set wireless\\.\\\${dev}\\.country=CN/set wireless.\\\${dev}.country=US/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 调整WIFI加密方式
sed -i "s/set wireless\\.default_\\\${dev}\\.encryption=none/set wireless.default_\\\${dev}.encryption='sae-mixed'/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# WIFI添加密码
sed -i "/set wireless\\.default_\\\${dev}\\.network=lan/a\                                        set wireless.default_\\\${dev}.key='88888888'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# 隐藏WIFI
sed -i "/set wireless\\.default_\\\${dev}\\.mode=ap/a\                                        set wireless.default_\\\${dev}.hidden='1'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh

# --- Zabbix Proxy SQLite3 强制转换 (核心添加部分) ---
# 1. 查找 Zabbix Makefile 的位置
ZABBIX_MAKE=$(find feeds/packages/ -name Makefile | grep "admin/zabbix/Makefile")

if [ -n "$ZABBIX_MAKE" ]; then
    echo "发现 Zabbix Makefile: $ZABBIX_MAKE，正在注入 SQLite3 配置..."
    
    # 2. 注入 libsqlite3 依赖
    # 在 DEPENDS 变量末尾追加依赖
    sed -i '/DEPENDS:=/ s/$/ +libsqlite3/' "$ZABBIX_MAKE"
    
    # 3. 替换数据库编译参数
    # 删除原有的 MySQL 和 PostgreSQL 条件判断逻辑
    sed -i '/CONFIG_ZABBIX_MYSQL/d' "$ZABBIX_MAKE"
    sed -i '/CONFIG_ZABBIX_POSTGRESQL/d' "$ZABBIX_MAKE"
    
    # 在 --disable-java 后插入强制的 --with-sqlite3 参数
    # 注意：使用带有转义的反斜杠以保持 Makefile 语法正确
    sed -i '/--disable-java/a \	--with-sqlite3 \\' "$ZABBIX_MAKE"
    
    echo "Zabbix Proxy 已成功强制转换为 SQLite3 版本。"
else
    echo "警告: 未找到 Zabbix Makefile，请确认 feeds 已更新。"
fi

# --- 防火墙规则添加 ---
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
