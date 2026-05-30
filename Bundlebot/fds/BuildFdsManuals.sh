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

# this script runs fdsbot to build fds manuals using revision and tags defined in config.sh
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

echo clean files
cd $CURDIR/../../Fdsbot
git clean -dxf >& /dev/null
cd $CURDIR
git clean -dxf >& /dev/null

cd $REPOROOT/bot/Bundlebot/nightly
OUTDIR=$REPOROOT/bot/Bundlebot/output
BUNDLETYPE=release
echo cloning fds-smv
./setup_repos.sh    -B $BUNDLETYPE -K fds-smv >& $OUTDIR/clone_fds-smv &
pid_fds_smv=$!

echo cloning test_bundles
./setup_repos.sh    -B $BUNDLETYPE -K test_bundles >& $OUTDIR/clone_test_bundles &
pid_test_bundles=$!

echo cloning cad
./setup_repos.sh -b -B $BUNDLETYPE -K cad -D >& $OUTDIR/clone_cad &
pid_cad=$!

echo cloning exp
./setup_repos.sh -b -B $BUNDLETYPE -K exp -D >& $OUTDIR/clone_exp &
pid_exp=$!

echo cloning fds
./setup_repos.sh -b -B $BUNDLETYPE -K fds -D >& $OUTDIR/clone_fds &
pid_fds=$!

echo cloning fig
./setup_repos.sh -b -B $BUNDLETYPE -K fig -D >& $OUTDIR/clone_fig &
pid_fig=$!

echo cloning out
./setup_repos.sh -b -B $BUNDLETYPE -K out -D >& $OUTDIR/clone_out &
pid_out=$!

echo cloning smv
./setup_repos.sh -b -B $BUNDLETYPE -K smv -D >& $OUTDIR/clone_smv &
pid_smv=$!

cd $REPOROOT/bot/Scripts
echo cloning hypre and sundials
./setup_repos.sh -3 -e >& /dev/null &
pid_3rd=$1
rm -rf $REPOROOT/libs

echo cloning wikis and webpages
./setup_repos.sh -w -e >& /dev/null &
pid_wiki=$1

wait $pid_3rd
echo hypre and sundials cloned

wait $pid_wiki
echo wikis and webpages cloned

wait $pid_fds_smv
echo fds_smv cloned

wait $pid_test_bundles
echo test_bundles cloned

wait $pid_cad
echo cad cloned

wait $pid_exp
echo exp cloned

wait $pid_fds
echo fds cloned

wait $pid_fig
echo fig cloned

wait $pid_out
echo out cloned

wait $pid_smv
echo smv cloned
echo all repos cloned
# build manuals
cd $REPOROOT/bot/Fdsbot
./run_fdsbot.sh -q firebot $MAILTO -U -r test_bundles $OWNER
