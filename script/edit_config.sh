#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# 修改默认IP
sed -i 's/192.168.1.1/10.0.1.254/g' package/base-files/files/bin/config_generate

# 添加TTL密码认证
sed -i "s/set system\.@system\[-1\]\.ttylogin='0'/set system.@system[-1].ttylogin='1'/g" package/base-files/files/bin/config_generate

# 调整默认主题
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 修改主机名
sed -i 's/ImmortalWrt/N60Pro/g' package/base-files/files/bin/config_generate

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


# 添加组播防火墙规则
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
