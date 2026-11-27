#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../bundle_lock.sh" || exit 1

OWNER=`whoami`

stop_release=0
upload_option=-U
gui_installer=()
while getopts "Ghkno:u" option; do
  case "$option" in
    G) gui_installer=(-G) ;;
    h) echo "Usage: BuildRelease.sh [-G] [-k] [-n] [-o OWNER] [-u]"
       echo "  -G  Build a GUI shell installer, plus a DMG on macOS"
       echo "  -n  Use the macOS release builder to create both installers"
       exit 0 ;;
    k) stop_release=1 ;;
    n) new_mac_release=1 ;;
    o) OWNER=$OPTARG ;;
    u) upload_option=-u ;;
    *) exit 1 ;;
  esac
done
shift "$((OPTIND - 1))"

if [ "$stop_release" = 1 ]; then
  bundle_stop BuildRelease.pid
  exit $?
fi

if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "x86_64" ]; then
  echo "Error: bundles cannot be built on Intel Macs, only ARM Macs are supported." >&2
  exit 1
fi

release_upload_owner=$OWNER
if [ "$upload_option" = -u ]; then
  if ! release_upload_owner=$(whoami) || [ -z "$release_upload_owner" ]; then
    echo "***error: could not determine the upload owner with whoami" >&2
    exit 1
  fi
fi

bundle_lock_acquire BuildRelease.pid || exit 1

if [[ $(uname -s) == Darwin ]] && [[ -n $new_mac_release || ${#gui_installer[@]} -ne 0 ]]; then
  bash "$(dirname "$0")/BuildMacRelease.sh" "$@"
  exit $?
fi


# build a release bundle using revision and tags defined in config.sh .
source config.sh
export DISABLEPUSH=1

# for testing build bundle with a specified hash and tag
#export BUNDLE_FDS_HASH=889da6ae0
#export BUNDLE_FDS_TAG=FDS-6.9.1test
#export BUNDLE_SMV_HASH=xxxxx
#export BUNDLE_SMV_TAG=SMV-6.9.1test

CURDIR=`pwd`

echo ***cleaning bot repo
cd $CURDIR/../../Firebot
git clean -dxf  >& /dev/null
cd $CURDIR/output
git clean -dxf  >& /dev/null
cd $CURDIR/../nightly
git clean -dxf  >& /dev/null

cd $CURDIR/../nightly
./BuildNightly.sh -c -R -o "$OWNER" -r test_bundles "$upload_option" "${gui_installer[@]}" || exit $?

cd $CURDIR
TITLE="Bundle Test - $BUNDLE_FDS_TAG/$BUNDLE_FDS_HASH - $BUNDLE_SMV_TAG/$BUNDLE_SMV_HASH"
gh release edit FDS_TEST  -t "$TITLE" -R "github.com/$release_upload_owner/test_bundles"
