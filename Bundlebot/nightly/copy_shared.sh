#!/bin/bash
FDS=$1
TODIR=$2
#FDS=../../../fds/Build/ompi_gnu_osx/fds_ompi_gnu_osx
FILES=`otool -L $FDS  | awk '{print $1 }' | grep mpi | grep -v fds`
for file in $FILES; do
  cp $file $TODIR/.
done
