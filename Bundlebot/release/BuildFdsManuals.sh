#!/bin/bash

MAILTO=
if [ "$BUNDLE_EMAIL" != "" ]; then
  MAILTO="-m $BUNDLE_EMAIL"
fi

OWNER="-o firemodels"
if [ "$BUNDLE_OWNER" != "" ]; then
  OWNER="-o $BUNDLE_OWNER"
fi

#*** parse command line options

while getopts 'hm:o:' OPTION
do
case $OPTION  in
  h)
   echo Usage:
   echo ./BUILD_fds_manuals.sh -o owner -m email_address
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

# this script runs firebot to build fds manuals using revision and tags defined in config.sh
source config.sh
export DISABLEPUSH=1

echo FDS manuals will be built using:
echo "     OWNER: $OWNER"
if [ "$MAILTO" == "" ]; then
echo "     email: not specified (use -m username@mailserver.xyz)"
else
echo "    MAILTO: $MAILTO"
fi
echo "   command: $0 $OWNER $MAILTO"
echo "  FDS repo: $BUNDLE_FDS_TAG $BUNDLE_FDS_HASH"
echo "  SMV repo: $BUNDLE_SMV_TAG $BUNDLE_SMV_HASH"
echo ""
echo "Press any key to continue or <CTRL> c to abort."
echo "Type $0 -h for other options"
read val

CURDIR=`pwd`

cd ../../..
REPOROOT=`pwd`
cd $CURDIR

echo ***clean files
cd $CURDIR/../../Firebot
git clean -dxf >& /dev/null
cd $CURDIR/output
git clean -dxf >& /dev/null
cd $CURDIR/../nightly
git clean -dxf >& /dev/null

echo ***clone repos
cd $REPOROOT/bot/Bundlebot/nightly
./clone_all_repos.sh $REPOROOT/bot/Bundlebot/nightly/output release >& /dev/null &
pid_all=$1

cd $REPOROOT/bot/Scripts
./setup_repos.sh -3 -e >& /dev/null &
pid_3rd=$1
rm -rf $REPOROOT/libs

./setup_repos.sh -w -e >& /dev/null &
pid_wiki=$1

wait $pid_all
wait $pid_3rd
wait $pid_wiki
echo ***repos cloned

# build manuals
cd $REPOROOT/bot/Firebot
./run_firebot.sh -q firebot $MAILTO -U -r test_bundles $OWNER
