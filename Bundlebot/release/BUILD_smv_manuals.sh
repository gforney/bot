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

while getopts 'm:o:' OPTION
do
case $OPTION  in
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
source config.sh

CURDIR=`pwd`

echo ***clean files
cd ../../Smokebot
git clean -dxf >& /dev/null
cd $CURDIR/output
git clean -dxf >& /dev/null
cd $CURDIR/../nightly
git clean -dxf >& /dev/null

cd $CURDIR


#echo ***updating repos
cd ../../Scripts
echo "setting up repos"
./setup_repos.sh -A
./update_repos.sh -w

cd $CURDIR/../../Smokebot
./run_smokebot.sh -C -c -u -J -f -q firebot $MAILTO -x $BUNDLE_FDS_REVISION -X $BUNDLE_FDS_TAG -y $BUNDLE_SMV_REVISION -Y $BUNDLE_SMV_TAG $OWNER -r test_bundles -U -R release
