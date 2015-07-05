#!/bin/bash

sudo cp /etc/bind/named.conf.forwarders-jvpn /etc/bind/named.conf.forwarders
sudo service bind9 reload

