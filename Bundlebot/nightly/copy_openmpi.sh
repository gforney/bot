#!/bin/bash
FROMDIR=$1
TODIR=$2

if [ ! -d $FROMDIR ]; then
  echo ***error: directory $FROMDIR does not exist
  exit
fi
if [ ! -d $TODIR ]; then
  echo ***error: directory $TODIR does not exist
  exit
fi
mkdir $TODIR/openmpi
cd $FROMDIR
tar cvf $TODIR/openmpi.tar .
cd $TODIR/openmpi
tar xvf ../$openmpi.tar
rm -f $TODIR/openmpi.tar

