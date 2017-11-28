image:
	GO_AGENT_PKG=github.com/clearcontainers/agent AGENT_BIN=cc-agent ./rootfs-builder/rootfs.sh clearlinux
	AGENT_BIN=cc-agent ./image-builder/image_builder.sh rootfs
