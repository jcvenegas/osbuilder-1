#!/bin/bash

set -e
if [ -n "$DEBUG" ] ; then
	set -x
fi

SCRIPT_NAME="${0##*/}"
IMAGE="kata-containers.img"
AGENT_BIN=${AGENT_BIN:-kata-agent}
MOUNT_DIR="/tmp/kata-mount-image"

die()
{
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}

OK()
{
	msg="$*"
	echo "[OK] ${msg}" >&2
}

info()
{
	echo -e "\e[1mINFO\e[0m: $*"
}

usage()
{
	cat <<EOT
Usage: ${SCRIPT_NAME} [options] <rootfs-dir>
	This script will create a Kata Containers image file based on the 
	<rootfs-dir> directory.

Options:
	-h Show this help
	-s Image size in MB default :$IMG_SIZE ENV: IMG_SIZE
	-o path to generate image file

Extra enviroment variables:
	AGENT_BIN: use it to change the expected agent binary name"
EOT
exit 1
}

while getopts hs:o: opt
do
	case $opt in
		h)	usage ;;
		s)	IMG_SIZE="${OPTARG}" ;;
		o)	IMAGE="${OPTARG}" ;;
	esac
done

shift $(($OPTIND - 1))

ROOTFS="$1"

[ -n "${ROOTFS}" ] || usage
[ -d "${ROOTFS}" ] || die "${ROOTFS} is not a directory"
# The kata rootfs image expect init and kata-agent to be installed
[ -x "${ROOTFS_DIR}/sbin/init" ] || die "/sbin/init is not installed int ${ROOTFS_DIR}"
OK "init is installed"
[ -x "${ROOTFS}/bin/${AGENT_BIN}" ] || \
	die "/bin/${AGENT_BIN} is not installed in ${ROOTFS_DIR}
	use AGENT_BIN env variable to change the expected agent binary name"
OK "Agent installed"
[ "$(id -u)" -eq 0 ] || die "$0: must be run as root"

BLOCK_SIZE=${BLOCK_SIZE:-4096}
IMG_SIZE=${IMG_SIZE:-80}

info "Creating raw disk with size ${IMG_SIZE}M"
qemu-img create -q -f raw "${IMAGE}" "${IMG_SIZE}M"
OK "Image file created"

# Kata runtime expect an image with just one partition
# The partition is the rootfs content

info "Creating partitions"
parted ${IMAGE} --script "mklabel gpt" \
"mkpart ext4 1M -1M"
OK "Partitions created"

# Get the loop device bound to the image file (requires /dev mounted in the
# image build system and root privileges)
DEVICE=$(losetup -P -f --show ${IMAGE})

#Refresh partition table
partprobe ${DEVICE}

mkdir -p "${MOUNT_DIR}"
info "Formating Image using ext4 format"
mkfs.ext4 -q -F -b "${BLOCK_SIZE}" "${DEVICE}p1"
OK "Image formated"

info "Mounting root paratition"
mount "${DEVICE}p1" "${MOUNT_DIR}"
OK "root paratition mounted"

#RERVED_BLOCKS_PERCENTAGE=3
#info "Set filesystem reserved blocks percentage to ${RERVED_BLOCKS_PERCENTAGE}%"
#tune2fs -m "${RERVED_BLOCKS_PERCENTAGE}" "${DEVICE}p1"

#TODO: Calculate disk size based on rootfs
ROOTFS_SIZE=$(du -B 1MB -s "${ROOTFS}" | awk '{print $1}')
AVAIL_DISK=$(df -B M --output=avail "${DEVICE}p1" | tail -1)
AVAIL_DISK=${AVAIL_DISK/M}
info "Free space root partition ${AVAIL_DISK} MB"
info "rootfs size ${ROOTFS_SIZE} MB"
info "Copying content from rootfs to root partition"
cp -a "${ROOTFS}"/* ${MOUNT_DIR}
#rsync -axHAX --quiet --progress "${ROOTFS}" "${MOUNT_DIR}"
OK "rootfs copied"

# Cleanup
sync
umount -l ${MOUNT_DIR}
fsck -D -y "${DEVICE}p1"
losetup -d "${DEVICE}"
info "Image created"
