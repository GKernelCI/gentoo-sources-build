# gentoo-sources builder script
script for automatically build gentoo-sources using [liquorix kernel configuration](https://github.com/damentz/liquorix-package)

The script must be run as root

```
Usage: ./kernel-build [-k][options]
 -k kernel version to install (example 5.14.14)

```

if the script cannot find the kernel version remember to run 
```
emerge --sync
```
for getting new gentoo-sources
