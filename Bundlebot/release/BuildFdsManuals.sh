#!/bin/bash
PIDFILE=`pwd`/BuildFdsManuals.pid

MAILTO=
if [ "$GH_EMAIL" != "" ]; then
  MAILTO="-m $GH_EMAIL"
fi

OWNER="-o firemodels"
if [ "$GH_OWNER" != "" ]; then
  OWNER="-o $GH_OWNER"
fi

#*** parse command line options

while getopts 'hkm:o:' OPTION
do
case $OPTION  in
  h)
   echo "Usage: $0 [-h] [-k] [-o owner] [-m email_address]"
   echo "-k - kill this script and all of its child processes"
   exit
   ;;
  k)
   if [ -e $PIDFILE ]; then
     PID=`head -1 $PIDFILE`
     echo ***killing process ID $PID and all child processes
     kill -9 -- -$PID
     rm -f $PIDFILE
   else
     echo ***warning: BuildFdsManuals.sh is not running
   fi
   exit
   ;;
  m)
   MAILTO="-m $OPTARG"
   ;;
  o)
   OWNER="-o $OPTARG"
   ;;
esac
done
shift $(($OPTIND-1))

echo $$ > $PIDFILE

# Get revision descriptions from the repositories beside the bot repository.
SCRIPTDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
FMROOT="$(cd -- "$SCRIPTDIR/../../.." && pwd)" || exit 1

#determine revisions for each repo
BOT_REV=$(cd -- "$FMROOT/bot" && git describe --dirty --long) || exit 1
CAD_REV=$(cd -- "$FMROOT/cad" && git describe --dirty --long) || exit 1
EXP_REV=$(cd -- "$FMROOT/exp" && git describe --dirty --long) || exit 1
FDS_REV=$(cd -- "$FMROOT/fds" && git describe --dirty --long) || exit 1
FIG_REV=$(cd -- "$FMROOT/fig" && git describe --dirty --long) || exit 1
OUT_REV=$(cd -- "$FMROOT/out" && git describe --dirty --long) || exit 1
SMV_REV=$(cd -- "$FMROOT/smv" && git describe --dirty --long) || exit 1

#determine branches for each repo
BOT_BRANCH=$(cd -- "$FMROOT/bot" && git rev-parse --abbrev-ref HEAD) || exit 1
CAD_BRANCH=$(cd -- "$FMROOT/cad" && git rev-parse --abbrev-ref HEAD) || exit 1
EXP_BRANCH=$(cd -- "$FMROOT/exp" && git rev-parse --abbrev-ref HEAD) || exit 1
FDS_BRANCH=$(cd -- "$FMROOT/fds" && git rev-parse --abbrev-ref HEAD) || exit 1
FIG_BRANCH=$(cd -- "$FMROOT/fig" && git rev-parse --abbrev-ref HEAD) || exit 1
OUT_BRANCH=$(cd -- "$FMROOT/out" && git rev-parse --abbrev-ref HEAD) || exit 1
SMV_BRANCH=$(cd -- "$FMROOT/smv" && git rev-parse --abbrev-ref HEAD) || exit 1

echo FDS manuals will be built using:
echo "     OWNER: $OWNER"
if [ "$MAILTO" == "" ]; then
echo "     email: not specified (use -m username@mailserver.xyz)"
else
echo "    MAILTO: $MAILTO"
fi
echo "   command: $0 $OWNER $MAILTO"
echo "  BOT repo: $BOT_REV/$BOT_BRANCH"
echo "  CAD repo: $CAD_REV/$CAD_BRANCH"
echo "  EXP repo: $EXP_REV/$EXP_BRANCH"
echo "  FDS repo: $FDS_REV/$FDS_BRANCH"
echo "  FIG repo: $FIG_REV/$FIG_BRANCH"
echo "  OUT repo: $OUT_REV/$OUT_BRANCH"
echo "  SMV repo: $SMV_REV/$SMV_BRANCH"

echo ""
echo "Press any key to continue or <CTRL> c to abort."
echo "Type $0 -h for other options"
read val

cd ../../Firebot
echo ./run_firebot.sh -f -q firebot $MAILTO -U -r test_bundles $OWNER
     ./run_firebot.sh -f -q firebot $MAILTO -U -r test_bundles $OWNER 

rm -f $PIDFILE
