#!/bin/bash
TODIR=$1
FDS=$2

ABORT=
CURDIR=`pwd`
SCRIPTDIR=$(dirname "${args}")
FDSBUILDDIR=$SCRIPTDIR/../../../fds/Build
if [ -d $FDSBUILDDIR ]; then
  cd $FDSBUILDDIR
  FDSBUILDDIR=`pwd`
  cd $CURDIR
else
  echo "***error: fds build directory, $FDSBUILDDIR, does not exit"
  ABORT=1
fi

FDSOSX=$FDSBUILDDIR/ompi_gnu_osx/fds_ompi_gnu_osx
FDSLINUX=$FDSBUILDDIR/ompi_gnu_linux/fds_ompi_gnu_linux
if [ "`uname`" == "Darwin" ]; then
  if [ "$FDS" == "" ]; then
    FDS=$FDSOSX
  fi
else
  if [ "$FDS" == "" ]; then
    FDS=$FDSLINUX
  fi
fi
if [ ! -d $TODIR ]; then
  echo "***error: directory $TODIR does not exist"
  ABORT=1
fi
if [ ! -e $FDS ]; then
  echo "***error: program $FDS does not exist"
  ABORT=1
fi
if [ "$ABORT" != "" ]; then
  exit
fi

if [ "`uname`" == "Darwin" ]; then
  FILES=`otool -L $FDS  | awk '{print $1 }' | grep mpi | grep -v fds`
else
  FILES=`ldd $FDS  | awk '{print $3 }' | grep mpi | grep -v fds`
fi
for file in $FILES; do
  if [ -e $file ]; then
    echo copying shared library $file to $TODIR
    cp $file $TODIR/.
  else
    echo "***error: shared library: $file does not exist"
  fi
done
echo shared library copy complete
