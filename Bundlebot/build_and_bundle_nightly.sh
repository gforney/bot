#!/bin/bash
FIREBOT_HOST=$1
MAILTO=$2

if [ "$FIREBOT_HOST" == "" ]; then
  exit 1
fi
if [ "$MAILTO" == "" ]; then
  exit 1
fi

JOPT="-J"
if [ "`uname`" == "Darwin" ] ; then
  JOPT=
fi


curdir=`pwd`

cd ../Firebot
./run_firebot.sh -c -C -B -g $FIREBOT_HOST -G \~firebot $JOPT -R test -T -m $MAILTO

cd $curdir
./run_bundlebot.sh -p $FIREBOT_HOST -w -g
