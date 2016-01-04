#!/bin/bash

JVPN_HOME=$(dirname $0)
JVPN_HOME=$(dirname $JVPN_HOME)

JVPN_FORWARD=$JVPN_HOME/forward

if [ -r $JVPN_FORWARD ]
then
    if ! cmp -s $JVPN_FORWARD /etc/bind/named.conf.forwarders
        then
        sudo cp /etc/bind/named.conf.forwarders /etc/bind/named.conf.forwarders-jvpn
        sudo cp $JVPN_FORWARD /etc/bind/named.conf.forwarders

        sudo service bind9 reload

        cat <<'EOF' > /tmp/resol.txt
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(8)
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 127.0.0.1
search local

EOF

        sudo cp /tmp/resol.txt /etc/resolv.conf
    else
        echo $JVPN_FORWARD /etc/bind/named.conf.forwarders both are same not doing anythng. >&2
    fi
else
    echo $JVPN_FORWARD not created yet. >&2
    echo run $0 again. >&2
fi
