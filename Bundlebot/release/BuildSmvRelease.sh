#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../bundle_lock.sh" || exit 1
# build a release bundle using revision and tags defined in config.sh .
gui_installer=()
while getopts "Ghk" option; do
  case "$option" in
    G) gui_installer=(-G) ;;
    h) echo "Usage: BuildSmvRelease.sh [-G] [-h] [-k]"
       echo "  -G  Build a shell installer with graphical setup and text fallback"
       exit 0 ;;
    k) exec bash "$(dirname "$0")/../nightly/BuildSmvNightly.sh" -k ;;
    *) exit 1 ;;
  esac
done

bundle_lock_acquire || exit 1
source config.sh

cd ../nightly
./BuildSmvNightly.sh -R -U "${gui_installer[@]}"
