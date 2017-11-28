#!/bin/bash

set -e

script_name="${0##*/}"
script_dir="$(dirname $(realpath -s $0))"
ROOTFS_DIR=${ROOTFS_DIR:-${PWD}/rootfs}
AGENT_VERSION=${AGENT_VERSION:-master}
GO_AGENT_PKG=${GO_AGENT_PKG:-github.com/kata-containers/agent}
AGENT_BIN=${AGENT_BIN:-kata-agent}

if [ -n "$DEBUG" ] ; then
	set -x
fi

usage(){
	cat <<EOT
USAGE: Build a Clear Containers 
${script_name} [options] <distro_name>

<distro_name> : Linux distribution to use as base OS.

Supported Linux distributions:

$(get_distros)

Options:
-h  : Show this help message
-a  : agent version DEFAULT: ${AGENT_VERSION} ENV: AGENT_VERSION 
-r  : rootfs directory DEFAULT: ${ROOTFS_DIR} ENV: ROOTFS_DIR

ENV VARIABLES:
GO_AGENT_PKG: Change the golang package url to get the agent source code
            DEFAULT: ${AGENT_REPO}
EOT
	exit 1
	
}

die()
{
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}

info()
{
	msg="$*"
	echo "INFO: ${msg}" >&2
}

OK()
{
	msg="$*"
	echo "INFO: [OK] ${msg}" >&2
}

get_distros() {
	cdirs=$(find "${script_dir}" -maxdepth 1 -type d)
	find ${cdirs} -maxdepth 1 -name rootfs_lib.sh -printf '%H\n' | while read dir; do  
		basename "${dir}"
	done
}


check_function_exist() {
	function_name="$1"
	[ "$(type -t ${function_name})" == "function" ] || die "${function_name} function was not defined"
}


while getopts c:hr: opt
do
	case $opt in
		a)	AGENT_VERSION="${OPTARG}" ;;
		h)	usage ;;
		r)	ROOTFS_DIR="${OPTARG}" ;;
	esac
done

shift $(($OPTIND - 1))

distro="$1"

[ -n "${distro}" ] || usage
distro_config_dir="${script_dir}/${distro}"

[ -d "${distro_config_dir}" ] || die "Not found configuration directory ${distro_config_dir}"
rootfs_lib="${distro_config_dir}/rootfs_lib.sh"
source "${rootfs_lib}"
rootfs_config="${distro_config_dir}/config.sh"
source "${rootfs_config}"

check_function_exist "build_rootfs"
mkdir -p ${ROOTFS_DIR}
build_rootfs ${ROOTFS_DIR}

info "Check init is installed"
[ -x "${ROOTFS_DIR}/sbin/init" ] || die "/sbin/init is not installed int ${ROOTFS_DIR}"
OK "init is installed"

info "Pull Agent source code"
go get -d "${GO_AGENT_PKG}" || true
OK "Pull Agent source code"

info "Build agent"
pushd "${GOPATH}/src/${GO_AGENT_PKG}"
make 
make install DESTDIR="${ROOTFS_DIR}"
popd
[ -x "${ROOTFS_DIR}/bin/${AGENT_BIN}" ] || die "/bin/${AGENT_BIN} is not installed in ${ROOTFS_DIR}"
OK "Agent installed"
