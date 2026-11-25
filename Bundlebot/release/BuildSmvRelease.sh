#!/bin/bash
# build a release bundle using revision and tags defined in config.sh .
gui_installer=()
while getopts "Gh" option; do
  case "$option" in
    G) gui_installer=(-G) ;;
    h) echo "Usage: BuildSmvRelease.sh [-G]"
       echo "  -G  Build a shell installer with graphical setup and text fallback"
       exit 0 ;;
    *) exit 1 ;;
  esac
done

source config.sh

cd ../nightly
./BuildSmvNightly.sh -R -U "${gui_installer[@]}"
