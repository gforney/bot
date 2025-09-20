#!/bin/bash
output=$1
CURRENT=$2
if [ "$output" == "" ]; then
  output=output
fi

if [ "$CURRENT" == "" ]; then
  gh release download SMOKEVIEW_TEST -p SMV_INFO.txt -R github.com/firemodels/test_bundles -D $output --clobber
  grep SMV_HASH     $output/SMV_INFO.txt | awk '{print $2}' > $output/SMV_HASH
  grep SMV_REVISION $output/SMV_INFO.txt | awk '{print $2}' > $output/SMV_REVISION
else
  CURDIR=`pwd`
  cd ../../../smv
  git rev-parse --short HEAD > $output/SMV_HASH             > $output/SMV_HASH
  git describe --abbrev | awk -F '-' '{print $1"-"$2"-"$3}' > $output/SMV_REVISION
  cd $CURDIR
fi
