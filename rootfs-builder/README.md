# Building a rootfs for Kata Containers Guest OS #

Kata Containers guest OS is created using `rootfs.sh`.

## Supported base OS ##

The `rootfs.sh` script support different based OS `rootfs`. To build
a `rootfs` based in a supported based OS run:

``` ./rootfs.sh <distro> ```

To check the supported `rootfs` based OS use:

```
./rootfs.sh -h
```

## Adding support for new base OS ##

The script `rootfs.sh` will look for directories that meets the following
structure:

- A bash script that called `rootfs_lib.sh`

This file must contain a function called `build_rootfs()` this function
must receive as first argument the path where the `rootfs` will be
populated.

- A bash file `config.sh`

This represents the specific configuration for each based OS. It must
provide configuration specific variables for users modify them as needed.
The config file will be loaded before execute `build_rootfs()` to provide
all the need configuration to the function.

### Expected rootfs directory content ###

After the function `build_rootfs` is called the script expects the rootfs
directory containt a init binary in `/sbin/init` and `/bin/kata-agent`.
