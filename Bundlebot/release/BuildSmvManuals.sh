#!/bin/bash
PIDFILE=`pwd`/BuildSmvManuals.pid

MAILTO=
if [ "$GH_EMAIL" != "" ]; then
  MAILTO="-m $GH_EMAIL"
fi

OWNER="-o firemodels"
if [ "$GH_OWNER" != "" ]; then
  OWNER="-o $GH_OWNER"
fi

PROCEED=

#*** parse command line options

while getopts 'hkm:o:y' OPTION
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
     echo ***warning: BuildSmvManuals.sh is not running
   fi
   exit
   ;;
  m)
   MAILTO="-m $OPTARG"
   ;;
  o)
   OWNER="-o $OPTARG"
   ;;
  y)
   PROCEED=1
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
FDS_REV=$(cd -- "$FMROOT/fds" && git describe --dirty --long) || exit 1
FIG_REV=$(cd -- "$FMROOT/fig" && git describe --dirty --long) || exit 1
SMV_REV=$(cd -- "$FMROOT/smv" && git describe --dirty --long) || exit 1

#determine branches for each repo
BOT_BRANCH=$(cd -- "$FMROOT/bot" && git rev-parse --abbrev-ref HEAD) || exit 1
FDS_BRANCH=$(cd -- "$FMROOT/fds" && git rev-parse --abbrev-ref HEAD) || exit 1
FIG_BRANCH=$(cd -- "$FMROOT/fig" && git rev-parse --abbrev-ref HEAD) || exit 1
SMV_BRANCH=$(cd -- "$FMROOT/smv" && git rev-parse --abbrev-ref HEAD) || exit 1

echo Smokeview manuals will be built using:
echo "     OWNER: $OWNER"
if [ "$MAILTO" == "" ]; then
echo "     email: not specified (use -m username@mailserver.xyz)"
else
echo "    MAILTO: $MAILTO"
fi
echo "   command: $0 $OWNER $MAILTO"
echo "  BOT repo: $BOT_REV/$BOT_BRANCH"
echo "  FDS repo: $FDS_REV/$FDS_BRANCH"
echo "  FIG repo: $FIG_REV/$FIG_BRANCH"
echo "  SMV repo: $SMV_REV/$SMV_BRANCH"
echo ""
if [ "$PROCEED" == "" ]; then
  echo "Press any key to continue or <CTRL> c to abort."
  echo "Type $0 -h for other options"
  read val
fi

CURDIR=`pwd`

cd ../../../
export REPOROOT=`pwd`
cd $CURDIR

echo ***clean files
cd $CURDIR/../../Smokebot
echo ./run_smokebot.sh -f -b -q firebot $MAILTO $OWNER -r test_bundles -U 
     ./run_smokebot.sh -f -b -q firebot $MAILTO $OWNER -r test_bundles -U 

git clean -dxf >& /dev/null
cd $CURDIR/../nightly/output
git clean -dxf >& /dev/null

echo ***update bot, web and wiki repos
cd $CURDIR/../../Scripts
echo "update bot, web and wiki repos"
./update_repos.sh -b
./update_repos.sh -w

cd $CURDIR/../../Smokebot
echo ./run_smokebot.sh -f -q firebot $MAILTO $OWNER -r test_bundles -R release -U 
     ./run_smokebot.sh -f -q firebot $MAILTO $OWNER -r test_bundles -R release -U 
rm -f $PIDFILE
