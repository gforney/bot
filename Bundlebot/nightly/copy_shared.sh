#!/bin/bash
TOLIBDIR=$1
TOBINDIR=$2

ABORT=
CURDIR=`pwd`
SCRIPTDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
FDSLINUX=$FDSBUILDDIR/impi_intel_linux/fds_impi_intel_linux
if [ "`uname`" == "Darwin" ]; then
  FDS=$FDSOSX
else
  FDS=$FDSLINUX
fi
if [ ! -d $TOLIBDIR ]; then
  echo "***error: directory $TOLIBDIR does not exist"
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
  FILES=`ldd $FDS  | awk '{print $3 }' | grep oneapi | grep -v fds`
fi
echo
echo ***copying shared fds files to $TOLIBDIR
echo
for file in $FILES; do
  if [ -e $file ]; then
    echo copying $file
    cp $file $TOLIBDIR/.
  else
    echo "***error: shared library: $file does not exist"
  fi
done
if [ "`uname`" == "Darwin" ]; then
  echo
  echo ***copying shared mpirun files to $TOBINDIR
  echo
  FILES=`otool -L $OPENMPI_BIN/mpirun  | grep homebrew | grep -v mpirun | awk '{print $1 }'`
  for file in $FILES; do
    if [ -e $file ]; then
      echo copying $file
      cp $file $TOBINDIR/.
    else
      echo "***error: shared library: $file does not exist"
    fi
  done
fi
