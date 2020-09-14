#!/bin/bash

WICKED_EXT_PATH="/etc/wicked/extensions"

# called by dracut
check() {
    local _program

    require_binaries ip wicked || return 1

    return 255
}

# called by dracut
depends() {
    echo "kernel-network-modules"
    local link=$(readlink $moddir/write-ifcfg.sh)
    [[ "$link" = "write-ifcfg-suse.sh" ]] && \
    [[ -d /etc/sysconfig/network ]] && \
        echo "ifcfg"
    [[ "$link" = "write-ifcfg-redhat.sh" ]] && \
    [[ -d /etc/sysconfig/network-scripts ]] && \
        echo "ifcfg"
    return 0
}

# called by dracut
installkernel() {
    return 0
}

# called by dracut
install() {
    local _arch _i _dir
    inst_multiple ip hostname sed
    inst_multiple ping ping6
    inst_multiple -o teamd teamdctl teamnl
    inst_multiple wicked
    inst_simple /etc/libnl/classid
    inst_libdir_file "libwicked*.so.*"
    inst_libdir_file "libdbus-1.so.*"
    inst_script "$moddir/ifup.sh" "/sbin/ifup"
    inst_script "$moddir/netroot.sh" "/sbin/netroot"
    inst_simple "$moddir/net-lib.sh" "/lib/net-lib.sh"
    inst_hook pre-udev 50 "$moddir/ifname-genrules.sh"
    inst_hook pre-udev 60 "$moddir/net-genrules.sh"
    inst_hook cmdline 91 "$moddir/dhcp-root.sh"
    inst_hook cmdline 92 "$moddir/parse-ibft.sh"
    inst_hook cmdline 95 "$moddir/parse-vlan.sh"
    inst_hook cmdline 96 "$moddir/parse-bond.sh"
    inst_hook cmdline 96 "$moddir/parse-team.sh"
    inst_hook cmdline 97 "$moddir/parse-bridge.sh"
    inst_hook cmdline 98 "$moddir/parse-ip-opts.sh"
    inst_hook cmdline 99 "$moddir/parse-ifname.sh"

    _arch=$(uname -m)

    [[ $hostonly ]] && {
        inst_multiple /etc/sysconfig/network/ifcfg-*
        inst_multiple -o /etc/sysconfig/network/ifroute-*
        inst_simple /etc/sysconfig/network/routes
        inst_multiple -o /var/lib/wicked/duid.xml /var/lib/wicked/iaid.xml
    }

    inst_libdir_file {"tls/$_arch/",tls/,"$_arch/",}"libnss_dns.so.*" \
        {"tls/$_arch/",tls/,"$_arch/",}"libnss_mdns4_minimal.so.*"

    dracut_need_initqueue
}

