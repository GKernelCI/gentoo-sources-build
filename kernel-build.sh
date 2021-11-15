#!/bin/bash

usage() {
  printf "Usage: $0 [-k][options]\n"
  printf " -k kernel version to install (example 5.14.14)\n"
  printf "\n"
  exit 1
}

remove_old_kernel() {
  emerge -C gentoo-sources
  rm -Rf /usr/src/*-gentoo*
  find /boot/ /lib/modules/ -mindepth 1 -maxdepth 1 -name \*gentoo\* ! -name \*$(uname -r) -exec rm -R {} \;
}

prepare_kernel() {
  emerge -b =gentoo-sources-$kernelversion --nodeps
  eselect kernel set linux-$kernelversion-gentoo
  wget https://raw.githubusercontent.com/damentz/liquorix-package/$kernelmajversion/master/linux-liquorix/debian/config/kernelarch-x86/config-arch-64
  sed -i "s/CONFIG_CRYPTO_CRC32C=m/CONFIG_CRYPTO_CRC32C=y/; s/CONFIG_FW_LOADER_USER_HELPER=y/CONFIG_FW_LOADER_USER_HELPER=n/; s/CONFIG_I2C_NVIDIA_GPU=/#CONFIG_I2C_NVIDIA_GPU=/; s/CONFIG_R8169=m/CONFIG_R8169=y/" config-arch-64
  #echo -e "CONFIG_SND_HDA_INPUT_BEEP=y\nCONFIG_SND_HDA_INPUT_BEEP_MODE=0" >> config-arch-64
  echo -e "CONFIG_AUFS_FS=y\nCONFIG_AUFS_BRANCH_MAX_127=y\nCONFIG_AUFS_BRANCH_MAX_511=n\nCONFIG_AUFS_BRANCH_MAX_1023=n\nCONFIG_AUFS_BRANCH_MAX_32767=n\nCONFIG_AUFS_HNOTIFY=y\nCONFIG_AUFS_EXPORT=n\nCONFIG_AUFS_XATTR=y\nCONFIG_AUFS_FHSM=y\nCONFIG_AUFS_RDU=n\nCONFIG_AUFS_DIRREN=n\nCONFIG_AUFS_SHWH=n\nCONFIG_AUFS_BR_RAMFS=y\nCONFIG_AUFS_BR_FUSE=n\nCONFIG_AUFS_BR_HFSPLUS=n\nCONFIG_AUFS_DEBUG=n" >> config-arch-64
  sed -i "s/CONFIG_ISO9660_FS=m/CONFIG_ISO9660_FS=y/" config-arch-64
}

aufs_patches() {
  cd /usr/src/linux-$kernelversion-gentoo/
  git clone --single-branch --branch aufs$kernelmajversion git://github.com/sfjro/aufs5-standalone.git
  patch -p1 < aufs5-standalone/aufs5-kbuild.patch
  patch -p1 < aufs5-standalone/aufs5-base.patch
  patch -p1 < aufs5-standalone/aufs5-mmap.patch
  cp -R aufs5-standalone/{Documentation,fs} .
  cp aufs5-standalone/include/uapi/linux/aufs_type.h include/uapi/linux/
  cd -
}

build_kernel() {
  genkernel --kernel-ld=ld.bfd --kernel-config=config-arch-64 --luks --lvm all
  XZ_OPT="--lzma1=preset=9e,dict=128MB,nice=273,depth=200,lc=4" tar --lzma -cf /var/cache/binpkgs/s/kernel.tar.lzma /boot/*$kernelversion-gentoo /lib/modules/$kernelversion-gentoo &
}

build_gnu_kernel() {
  cp -R /usr/src/linux-$kernelversion-gentoo/ /usr/src/linux-$kernelversion-gentoo-gnu/

  cd /usr/src/linux-$kernelversion-gentoo-gnu/
  wget https://linux-libre.fsfla.org/pub/linux-libre/releases/$kernelversion-gnu/deblob-$kernelmajversion https://linux-libre.fsfla.org/pub/linux-libre/releases/$kernelversion-gnu/deblob-check
  chmod +x deblob-$kernelmajversion deblob-check
  PYTHON="python2.7" ./deblob-$kernelmajversion
  cd -

  genkernel --kernel-ld=ld.bfd --kernel-config=config-arch-64 --luks --lvm --kerneldir=/usr/src/linux-$kernelversion-gentoo-gnu/ all
  XZ_OPT="--lzma1=preset=9e,dict=128MB,nice=273,depth=200,lc=4" tar --lzma -cf /var/cache/binpkgs/s/kernel-libre.tar.lzma /boot/*$kernelversion-gentoo-gnu /lib/modules/$kernelversion-gentoo-gnu &
  rm -Rf /usr/src/linux-$kernelversion-gentoo-gnu/
}

clean(){
  rm -Rf config-arch-64
}

# Main
if [ $(id -u) != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
fi

while getopts ":k:h:" opt; do
  case $opt in
    k)
      kernelversion=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done
if [ $OPTIND -eq 1 ]; then usage; fi
kernelmajorversion=${kernelversion%.*}

if [ ! -d '/var/cache/binpkgs/s/' ]; then
        mkdir -p /var/cache/binpkgs/s/
fi

export BINPKG_COMPRESS="xz" XZ_OPT="--x86 --lzma2=preset=9e,dict=128MB,nice=273,depth=200,lc=4"


remove_old_kernel
prepare_kernel
aufs_patches
build_kernel
cd /usr/src/linux/
make clean
make LD=ld.bfd prepare
make LD=ld.bfd modules_prepare
wait
LD=ld.bfd emerge -b @module-rebuild
clean
