#!/bin/bash
set -euo pipefail

pushd /usr/lib/cf-modules

KVER=$(ls /usr/src/kernels | head -n1)
KDIR=$(ls -d /usr/src/kernels/* | head -n1)

dkms add .
KVER=$KVER dkms build cf-modules/1.0 -k $KVER

# cat /var/lib/dkms/cf-modules/1.0/build/make.log

dkms install cf-modules/1.0 -k $KVER

popd
