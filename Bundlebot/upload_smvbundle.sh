#!/bin/bash
FROM_DIR=$1
FROM_FILE=$2
RELEASEBUNDLEDIR=$3
RELEASEBRANCH=$4
GH_OWNER_ARG=$5
GH_REPO_ARG=$6

CURDIR=`pwd`
cd $HOME/$RELEASEBUNDLEDIR/../bot/Bundlebot
SCRIPTDIR=`pwd`
cd $CURDIR

if [ ! -e $HOME/$FROM_DIR/$FROM_FILE ] ; then
  echo "***error: $FROM_FILE does not exist in $HOME/$FROM_DIR"
  exit
fi

if [ "$RELEASEBUNDLEDIR" != "" ]; then
  cd $HOME/$RELEASEBUNDLEDIR
  echo uploading $FROM_FILE to github
  gh release upload $RELEASEBRANCH $HOME/$FROM_DIR/$FROM_FILE  -R github.com/$GH_OWNER_ARG/$GH_REPO_ARG --clobber
  if [ "`uname`" == "Darwin" ] ; then
    platform=osx
  else
    platform=linux
  fi
  if [ "$platform" == "linux" ]; then
    cd $SCRIPTDIR/../../smv
    SMV_SHORT_HASH=`git rev-parse --short HEAD`
    cd $SCRIPTDIR
    ./setreleasetitle.sh smv $SMV_SHORT_HASH
  fi
fi

