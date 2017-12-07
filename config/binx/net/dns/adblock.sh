#!/bin/zsh


WM=stumpwm

blocklist=~/.system/config/ip/block
dnsinterceptlist=~/.system/ubuntu/etc/bind/named.conf.intercept-zones

function main() {

    process_arg $@

    if (( ${+domain} )) ; then
        if [ -w ~/.system/config/ip/block ] ; then
            if ! grep $domain ~/.system/config/ip/block ; then
                print $domain >> ~/.system/config/ip/block
                cat <<EOF | tee --append $dnsinterceptlist
zone "$domain" {
        type master;
        file "/etc/bind/db.intercept";
};

EOF
            else
                print already presnt in ~/.system/config/ip/block
                grep $domain ~/.system/config/ip/block
            fi
        fi
    else
        echo > $dnsinterceptlist
        foreach d ( $(sort -u ~/.system/config/ip/block | sed '/^$/d' ) ) {
                cat <<EOF | tee --append $dnsinterceptlist
zone "$d" {
        type master;
        file "/etc/bind/db.intercept";
};

EOF
        }
    fi
}

function process_arg() {
    warn=1
    error=1

    disable_file=~/.var/comm/disable/$pgm
    set -- $(getopt -n $pgm -o hdrsivwega: -- $@)
    while [ $# -gt 0 ]
    do
        case $1 in
            (-a) eval domain=$2; shift;;
            (-i) interactive=1;;
            (-g) generate=1;;
            (-v) verbose=1;;
            (-s)
                if [ -f $disable_file ] ; then
                     notify $pgm is disabled;
                     exit -1;
                else
                    notify $pgm is enabled;
                    exit 0;
                fi
                ;;
            (-d)
                if [ -f $disable_file ] ; then
                     notify $pgm is already disabled;
                else
                 if mkdir -p $(dirname $disable_file); touch $disable_file ; then
                     sync
                     notify $pgm is disabled;
                 fi
                fi
                exit;;
            (-r)
                if [ -f $disable_file ] ; then
                    sync
                    rm -f $disable_file && notify $pgm is enabled;
                else
                    notify $pgm is already enabled;
                fi
                exit;;
            (-w) warn="";;
            (-e) error="";;
            (-h) help;
                 exit;;
            (--) shift; break;;
            (-*) echo "$0: error - unrecognized option $1" 1>&2; help; exit 1;;
            (*)  break;;
        esac
        shift
    done
}

function help() {
    cat <<'EOF'
            -a: eval account=$2; shift;;
            -i: interactive=1;;
            -v: verbose=1;;
            -d: touch $disable_file;;
            -r: rm -f $disable_file;;
            -w: warn=1;;
            -e: error=1;;
            -h: help;;
EOF

}

function error() {
    notify "$*"
    logger "$*"
}

function warn() {
    if [ $warn ] ; then
        notify "$*"
    fi
    logger "$*"
}

function verbose() {
    if [ $verbose ] ; then
        notify "$*"
    fi
    logger "$*"
}

function notify() {
    if [ -t 1 ] ; then
        # echo -e "${pgm}:" "$*" >&2
        print "${pgm}:" "$*" >&2
    else
        notify-send "${pgm}:" "$*"
    fi
}

function logger() {
    #creating prolem
    command logger -p local1.notice -t ${pgm} -i - $USER : "$*"
}

pgm=$(basename $0)

main $@
