#!/bin/bash

if [ -r /etc/bind/named.conf.forwarders-jvpn ]
then
    sudo cp /etc/bind/named.conf.forwarders-jvpn /etc/bind/named.conf.forwarders
    sudo service bind9 reload
    sudo rm -f /etc/bind/named.conf.forwarders-jvpn
else
    echo /etc/bind/named.conf.forwarders-jvpn do not exists, not doing anything. >&2
fi
