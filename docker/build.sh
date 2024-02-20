#!/bin/bash

if dpkg-buildpackage --help | grep "\-\-post\-clean" 2>/dev/null >/dev/null; then
  DPKG_BUILDPACKAGE="dpkg-buildpackage --post-clean --pre-clean -b -us -uc"
else
  DPKG_BUILDPACKAGE="dpkg-buildpackage -b -us -uc"
fi

# Ensure /owrx/ is bind-mounted
[ -d /owrx/ ] || exit 1

echo "+++++ APT update/upgrade"
apt update
apt upgrade -y

cd /usr/src || exit 1

ARCH=$(uname -m)

echo "+++++ Installing SDRPlay API"
case $ARCH in
  arm*) SDRPLAY_BINARY=SDRplay_RSP_API-ARM32-3.07.2.run ;;
  aarch64*) SDRPLAY_BINARY=SDRplay_RSP_API-Linux-3.14.0.run ;;
  x86_64*) SDRPLAY_BINARY=SDRplay_RSP_API-Linux-3.14.0.run ;;
esac
wget --no-http-keep-alive https://www.sdrplay.com/software/$SDRPLAY_BINARY
sh $SDRPLAY_BINARY --noexec --target sdrplay
patch --verbose -Np0 </tmp/sdrplay/$SDRPLAY_BINARY.patch
pushd sdrplay
mkdir -p /etc/udev/rules.d
./install_lib.sh
popd
rm -rf sdrplay $SDRPLAY_BINARY

echo "+++++ OWRX+ build script..."
wget "$BUILDSCRIPT"
SCRIPT=$(basename "$BUILDSCRIPT")
chmod +x ./$SCRIPT
./$SCRIPT $BUILDSCRIPT_ARGS || exit 1

# Copy the built packages to /owrx/ (which should be bind-mounted)
cp -a /usr/src/owrx-output/$ARCH/* /owrx/ || exit 1

# Correct ownership of the artifacts.
# Without this, the artifacts directory and it's contents end up owned
# by root instead of the local user on Linux boxes
chown -R --reference=/owrx /owrx/*
