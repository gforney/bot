#!/bin/bash
smokebotdir=$1

CURDIR=`pwd`
if [ "$smokebotdir" == "" ]; then
  cd ../../Smokebot
#  cd ../../../smv/Smokebot
  smokebotdir=`pwd`
  cd $CURDIR
fi

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
source config.sh

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

echo ***clean files
cd $smokebotdir
git clean -dxf >& /dev/null
cd $CURDIR/output
git clean -dxf >& /dev/null
cd $CURDIR/../nightly/output
git clean -dxf >& /dev/null

echo ***cloning repos
cd $smokebotdir
echo "setting up repos"
./setup_repos.sh -b -D
./update_repos.sh -w

cd $smokebotdir
echo ./run_smokebot.sh -f -q batch4 $MAILTO $OWNER -r test_bundles -U 
     ./run_smokebot.sh -f -q batch4 $MAILTO $OWNER -r test_bundles -U 
