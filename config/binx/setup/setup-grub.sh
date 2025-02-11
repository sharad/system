#!/usr/bin/env bash


# sudo lvcreate vds5DISKIDsys01 -L 20M -n boot
# sudo mkfs.ext4 /dev/mapper/vdsDISKIDXsys01-boot
# sudo mount /dev/mapper/vdsDISKIDXsys01-boot /mnt
# sudo mkdir /mnt/grub
# sudo cp ~/.setup/grub.cfg /mnt/grub
# sudo mkdir /mnt/grub/themes
# sudo cp  /gnu//store/wlf9ccsl9pmch1dyv5x8c2gdngwn9m5i-grub-image.png /mnt/grub/themes
# sudo mount /boot
# sudo mount /boot/efi
# sudo mount -o remount,rw /boot
# sudo mount -o remount,rw /boot/efi
# guix install grub grub-efi grub-hybrid
# ls /boot/efi/EFI
# sudo grub-install  --boot-directory /mnt/ --efi-directory /boot/efi/ --bootloader-id=Loader
# ls /boot/efi/EFI


function main()
{
    while getopts "h?vd:g:i:-n" opt; do
        case "$opt" in
            h|\?)
                show_help
                exit 0
                ;;
            d) DEVICE=$OPTARG
               ;;
            v)  verbose=1
                ;;
            g)  GRUB_DIR=$OPTARG
                ;;
            n)  EFI_NAME=$OPTARG
                ;;
            i) INSTALL=1
               ;;
        esac
    done

    shift $((OPTIND-1))

    if which grub-install
    then
        echo grub-install is not available >&2
        echo install it with >&2
        echo guix install grub grub-efi grub-hybrid >&2
        exit -1
    fi
    if which lsblk
    then
        echo lsblk is not available >&2
        echo install it with >&2
        echo guix install util-linux-with-udev >&2
        exit -1
    fi

    if which mountpoint
    then
        echo mountpoint is not available >&2
        echo install it with >&2
        echo guix install util-linux-with-udev >&2
        exit -1
    fi

    if [ ! "$INSTALL" ]
    then
        echo use -i to install by efibootmgr >&2
    fi

    if [ ! "$DEVICE" ]
    then
        echo boot device not passed >&2
        echo pass boot device using -d device-path >&2
        exit -1
    fi

    if [ ! "$GRUB_DIR" ]
    then
        GRUB_DIR=~/.setup/grub
    fi

    if [ ! "$EFI_NAME" ]
    then
        EFI_NAME=Loader
    fi

    if [ -d $GRUB_DIR/grub ]
    then
        echo $GRUB_DIR/grub directory not present >&2
        exit -1
    fi

    if [ -r $GRUB_DIR/grub/grub.cfg ]
    then
        echo $GRUB_DIR/grub/grub.cfg file not present >&2
        exit -1
    fi

    if [ -d $GRUB_DIR/grub/themes ]
    then
        echo $GRUB_DIR/grub/themes directory not present >&2
        exit -1
    fi

    MOUNTPOINT=/tmp/BOOTDIR_$$

    if check_device $DEVICE
    then
        if sudo mount /boot/ &&
            sudo mount /boot/efi/ &&
            sudo mount -o remount,rw /boot/efi &&
            sudo mount $DEVICE $MOUNTPOINT
        then

            trap "umount_all $DEVICE $MOUNTPOINT" EXIT

            if check_mountdir $MOUNTPOINT
            then
                sudo mkdir $MOUNTPOINT/grub
                sudo cp  $GRUB_DIR/grub/grub.cfg --target-directory=$MOUNTPOINT/grub/
                sudo cp -r $GRUB_DIR/grub/themes --target-directory=$MOUNTPOINT/grub/

                if [ "$INSTALL" ]
                then
                    if sudo sudo grub-install  --boot-directory /mnt/ --efi-directory /boot/efi/ --bootloader-id="$EFI_NAME"
                    then
                        echo Boot setup done for $DEVICE
                    else
                        echo if any issue seen consider deleting
                        echo rm /sys/firmware/efi/efivars/dump-type0-\*
                    fi
                else
                    eho installed by grub-install as -i option not passed >&2
                fi
            fi

            sudo umount $MOUNTPOINT
            sudo umount $DEVICE
            sudo umount /boot/efi
            sudo umount /boot/

        fi
    fi

}

function umount_all()
{
    DEVICE=$1
    MOUNTPOINT=$2

    sudo umount /boot/efi/
    sudo umount /boot/
    sudo umount $DEVICE
    sudo $MOUNTPOINT
}

function check_device()
{
    DEVICE=$1
    if [ ! -e $DEVICE ]
    then
        echo device $DEVICE not exists >&2
        exit -1
    fi

    if [ ! -b $DEVICE ]
    then
        echo device $DEVICE not block device >&2
        exit -1
    fi

    for line in $(lsblk --bytes --pairs --paths -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT $DEVICE | tr ' ' '\n' | sed -e 's@^@__DEVICE_@g')
    do
        eval $line
    done

    if [ $__DEVICE_FSTYPE != "ext4" ]
    then
        echo $DEVICE filesystem is not ext4 , it is $__DEVICE_FSTYPE >&2
        exit -1
    fi

    if [ "$__DEVICE_MOUNTPOINT" ]
    then
        echo $DEVICE is already in use, on "$__DEVICE_MOUNTPOINT"
        exit -1
    fi

    if [ "$__DEVICE_TYPE" -ne "lvm" -a "$__DEVICE_TYPE" -ne "part" ]
    then
        echo $DEVICE type is "$__DEVICE_TYPE", whcih is not lvm or partition >&2
        exit -1
    fi

    __DEVICE_SIZE_MB=$(( $__DEVICE_SIZE / (1024 * 1024) ))
    MIN_SIZE_MB=200
    MAX_SIZE_MB=300
    MIN_SIZE=$(( $MIN_SIZE_MB * 1024 * 1024 )) # 200MB
    MAX_SIZE=$(( $MAX_SIZE_MB * 1024 * 1024 )) # 300MB
    if [ $__DEVICE_SIZE -lt $MIN_SIZE ]
    then
        __DEVICE_SIZE_MB=$(( $__DEVICE_SIZE / (1024 * 1024) ))
        echo $DEVICE size is ${__DEVICE_SIZE_MB} MB, which is less than minimum $MIN_SIZE_MB MB >&2
        exit -1
    fi
    if [ $__DEVICE_SIZE -gt $MAX_SIZE ]
    then
        __DEVICE_SIZE_MB=$(( $__DEVICE_SIZE / (1024 * 1024) ))
        echo $DEVICE size is ${__DEVICE_SIZE_MB} MB, which is greater than $MAX_SIZE_MB MB >&2
        exit -1
    fi

    lsblk --json -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT $DEVICE
}

function check_mountdir()
{
    MOUNTPOINT=$2
    if [ ! "$MOUNTPOINT" ]
    then
        echo no mount point passed >&2
        exit -1
    fi

    if ! mountpoint "$MOUNTPOINT"
    then
        echo directory path "$MOUNTPOINT" is not a mountpoint >&2
        exit -1
    fi
    if ls -1 "$MOUNTPOINT"  | grep -E -v 'grub|lost\+found|skip' | wc -l | test 0 -lt
    then
        echo "$MOUNTPOINT" may be containing some other fielsystem which may be useful, so existing >&2
        echo below is listing of "$MOUNTPOINT" .&2
        echo ls -l "$MOUNTPOINT"
        ls -l "$MOUNTPOINT"
        exit -1
    fi
}

function show_help()
{
    pgm=$(basename $0)
    cat <<EOF
$pgm: mount cryfs filesystema
  -h|-?                show this help
  -v                   verbose
  -d device_for_grub   device to setup grub installation.
  -g grub_dir          grub directory path
  -i                   to install grub
EOF
    exit 0
}

main "$@"
exit 0
