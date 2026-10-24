#!/bin/bash
PIDFILE=`pwd`/BuildSmvRelease.pid

#---------------------------------------------
#                   USAGE
#---------------------------------------------

function USAGE {
  echo ""
  echo "Usage: $0 [-h] [-k]"
  echo ""
  echo "Build a Smokeview release bundle."
  echo ""
  echo "Options:"
  echo "-h - display this message"
  echo "-k - kill this script and all of its child processes"
}

while getopts ":kh" OPTION; do
  case $OPTION in
    k)
      if [ -e $PIDFILE ]; then
        PID=`head -1 $PIDFILE`
        echo ***killing process ID $PID and all child processes
        kill -9 -- -$PID
        rm -f $PIDFILE
      else
        echo ***warning: BuildSmvRelease.sh is not running
      fi
      exit
      ;;
    h)
      USAGE
      exit 0
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      USAGE >&2
      exit 1
      ;;
  esac
done

echo $$ > $PIDFILE

# build a release bundle using revision and tags defined in config.sh .
source config.sh

cd ../nightly
./BuildSmvNightly.sh -C -R -u

rm -f $PIDFILE
