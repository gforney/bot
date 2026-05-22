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
   echo ./BuildSmvManuals.sh -o owner -m email_address
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

# this script runs smokebot to build smokeview manuals using revision and tags defined in config.sh
source ../fds/config.sh

echo Smokeview manuals will be built using:
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

echo ***clean files
cd $CURDIR/../../Smokebot
git clean -dxf >& /dev/null
cd $CURDIR
git clean -dxf >& /dev/null

cd $CURDIR/../../Scripts
OUTDIR=$REPOROOT/bot/Bundlebot/smv/output
BUNDLETYPE=release

echo "cloning hypre and sundials"
./setup_repos.sh -3 -e  >& /dev/null &
pid_third=$!
rm -rf $CURDIR/../../../libs

echo "cloning wiki and webpages"
./setup_repos.sh -w -e >& /dev/null &
pid_www=$!

echo cloning cfast
./setup_repos.sh -b -B $BUNDLETYPE -K cfast -D >& $OUTDIR/clone_cfast &
pid_cfast=$!

echo cloning fds
./setup_repos.sh -b -B $BUNDLETYPE -K fds -D >& $OUTDIR/clone_fds &
pid_fds=$!

echo cloning fig
./setup_repos.sh -b -B $BUNDLETYPE -K fig -D >& $OUTDIR/clone_fig &
pid_fig=$!

echo cloning smv
./setup_repos.sh -b -B $BUNDLETYPE -K smv -D >& $OUTDIR/clone_smv &
pid_smv=$!

echo cloning test_bundles
./setup_repos.sh    -B $BUNDLETYPE -K test_bundles >& $OUTDIR/clone_test_bundles &
pid_test_bundles=$!

wait $pid_third
echo "hypre and sundials repos cloned"

wait $pid_www
echo "wiki and web pages repos cloned"

wait $pid_cfast
echo cfast cloned

wait $pid_fds
echo fds cloned

wait $pid_fig
echo fig cloned

wait $pid_smv
echo smv cloned

wait $pid_test_bundles
echo test_bundles cloned

cd $CURDIR/../../Smokebot
./run_smokebot.sh -f -q firebot $MAILTO  -r test_bundles -U
