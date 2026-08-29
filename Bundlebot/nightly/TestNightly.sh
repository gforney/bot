#!/bin/bash

case "$(uname -s)" in
  Linux*)  OS=linux ;;
  Darwin*) OS=osx ;;
esac
SUFFIX=lnx
if [ "$OS" == "osx" ]; then
 SUFFIX=osx
fi

INFO=FDS_INFO.txt
TOC=FDS_TOC.txt
rm -f "$INFO" "$TOC"
gh release download FDS_TEST -p "$INFO" -D . -R github.com/firemodels/test_bundles
FDS_REVISION=$(awk '$1 == "FDS_REVISION" {print $2; exit}' "$INFO")
SMV_REVISION=$(awk '$1 == "SMV_REVISION" {print $2; exit}' "$INFO")
PLATFORM=$SUFFIX
BUNDLENAME="${FDS_REVISION}_${SMV_REVISION}_${PLATFORM}.sh"
gh release view FDS_TEST -R github.com/firemodels/test_bundles | grep nightly_$SUFFIX | awk '{print $2}' > $TOC

while IFS= read -r filename; do
  if [[ "$filename" == $BUNDLENAME ]]; then
   echo bundle exists
    exit 1
  fi
done < "$TOC"
echo bundle does not exist
exit 0
 
