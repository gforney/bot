#!/bin/bash

case "$(uname -s)" in
  Linux*)  OS=linux ;;
  Darwin*) OS=osx ;;
esac
SUFFIX=nightly_lnx
if [ "$OS" == "osx" ]; then
 SUFFIX=_nightly_osx
fi

INFO=FDS_INFO.txt
TOC=FDS_TOC.txt
rm -f "$INFO" "$TOC"
gh release download FDS_TEST -p "$INFO" -D . -R github.com/firemodels/test_bundles
FDS_REVISION=$(awk '$1 == "FDS_REVISION" {print $2; exit}' "$INFO")
SMV_REVISION=$(awk '$1 == "SMV_REVISION" {print $2; exit}' "$INFO")
BUNDLENAME="${FDS_REVISION}_${SMV_REVISION}_${SUFFIX}.sh"
gh release view FDS_TEST -R github.com/firemodels/test_bundles | grep $SUFFIX | awk '{print $2}' > $TOC

while IFS= read -r filename; do
  if [[ "$filename" == $BUNDLENAME ]]; then
    exit 1
  fi
done < "$TOC"
exit 0
