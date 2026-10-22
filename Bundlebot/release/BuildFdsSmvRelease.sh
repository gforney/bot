#!/bin/bash
PIDFILE=`pwd`/BuildRelease.pid

#---------------------------------------------
#                   USAGE
#---------------------------------------------

function USAGE {
  echo ""
  echo "Usage: $0 [-h] [-k]"
  echo ""
  echo "Build FDS and Smokeview release bundles."
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
        echo ***warning: BuildRelease.sh is not running
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

OWNER=`whoami`
CURDIR=`pwd`

# Get revision descriptions from the repositories beside the bot repository.
SCRIPTDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
FMROOT="$(cd -- "$SCRIPTDIR/../../.." && pwd)" || exit 1

#determine revisions for each repo
BOT_REV=$(cd -- "$FMROOT/bot" && git describe --dirty --long) || exit 1
FDS_REV=$(cd -- "$FMROOT/fds" && git describe --dirty --long) || exit 1
SMV_REV=$(cd -- "$FMROOT/smv" && git describe --dirty --long) || exit 1

#determine branches for each repo
BOT_BRANCH=$(cd -- "$FMROOT/bot" && git rev-parse --abbrev-ref HEAD) || exit 1
FDS_BRANCH=$(cd -- "$FMROOT/fds" && git rev-parse --abbrev-ref HEAD) || exit 1
SMV_BRANCH=$(cd -- "$FMROOT/smv" && git rev-parse --abbrev-ref HEAD) || exit 1

echo "   command: $0 $OWNER $MAILTO"
echo "  BOT repo: $BOT_REV/$BOT_BRANCH"
echo "  FDS repo: $FDS_REV/$FDS_BRANCH"
echo "  SMV repo: $SMV_REV/$SMV_BRANCH"

echo ""
echo "Press any key to continue or <CTRL> c to abort."
echo "Type $0 -h for other options"
read val

cd $CURDIR/../nightly
./BuildNightly.sh -c -f -R -o $OWNER -r test_bundles -u

cd $CURDIR
TITLE="Bundle Test - $BUNDLE_FDS_TAG/$BUNDLE_FDS_HASH - $BUNDLE_SMV_TAG/$BUNDLE_SMV_HASH"
gh release edit FDS_TEST  -t "$TITLE" -R github.com/$OWNER/test_bundles
rm -f $PIDFILE
