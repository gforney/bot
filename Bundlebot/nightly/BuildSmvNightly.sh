#!/bin/bash
curdir=`pwd`

S_HASH=
S_REVISION=

#S_HASH=2f257722a
#S_REVISION=SMV-6.10.5-249

#---------------------------------------------
#                   usage
#---------------------------------------------

function usage {
echo ""
echo "BUILDSmvNightly.sh usage"
echo ""
echo "Options:"
echo "-h - display this message"
echo "-u - upload bundle file to GitHub owner: `whoami`"
echo "-U - upload bundle file to GitHub owner: $GHOWNER"
exit 0
}

UPLOADBUNDLE=
export BUILDING_release=
OUTPUT_USAGE=

while getopts 'huUR' OPTION
do
case $OPTION  in
  h)
   OUTPUT_USAGE=1
   ;;
  R)
   export BUILDING_release=1
   ;;
  u)
   GHOWNER=`whoami`
   UPLOADBUNDLE=1
   ;;
  U)
   UPLOADBUNDLE=1
   ;;
esac
done
shift $(($OPTIND-1))

if [ "$BUILDING_release" == "" ]; then
  if [ "$GHOWNER" == "" ]; then
    GHOWNER=firemodels
  fi
else
  git tag -a $BUNDLE_SMV_TAG -m "tag for smokeview release" >> $outdir/stage2_clone 2>&1
  GHOWNER=`whoami`
fi
if [ "$OUTPUT_USAGE" != "" ]; then
  usage
fi

#*** determine platform script is running on

platform=linux
platform2=lnx_intel
comp=intel
if [ "`uname`" == "Darwin" ] ; then
  platform="osx"
  platform2="osx_intel"
  if [ "`uname -m`" == "arm64" ] ; then
    platform2="osx_arm"
  fi
  comp=gnu
fi

cd ../../..
reporoot=`pwd`
basereporoot=`basename $reporoot`

cd $reporoot/smv
echo updating smv repo
git remote update
git merge firemodels/master
git merge origin/master

if [ "$BUILDING_release" != "" ]; then
  ERROR=
  if [ "$BUNDLE_SMV_HASH" == "" ]; then
    echo ***error: environment variable BUNDLE_SMV_HASH not defined
    ERROR=1
  fi
  if [ "$BUNDLE_SMV_TAG" == "" ]; then
    echo ***error: environment variable BUNDLE_SMV_TAG not defined
    ERROR=1
  fi
  if [ "$ERROR" != "" ]; then
    exit
  fi
fi

echo "*** get smv repo revision"
if [ "$BUILDING_release" == "" ]; then
  cd $reporoot/bot/Bundlebot/nightly/output
  outdir=`pwd`
  cd $reporoot/bot/Bundlebot/nightly
  ./get_hash_revisions.sh $outdir $S_HASH $S_REVISION >& $outdir/stage1_hash
  smv_hash=`head -1 $outdir/SMV_HASH`
else
  cd $reporoot/bot/Bundlebot/release/output
  outdir=`pwd`
  smv_hash=$BUNDLE_SMV_HASH
fi

cd $reporoot/bot/Bundlebot/nightly
./clone_smvrepo.sh $smv_hash $BUILDING_release >& $outdir/stage2_clone

cd $reporoot/smv
if [ "$BUILDING_release" == "" ]; then
  smv_revision=`git describe --abbrev=7 --dirty --long`
else
  smv_revision=$BUNDLE_SMV_TAG
fi
echo "***     smv_hash: $smv_hash"
echo "*** smv_revision: $smv_revision"

#build apps
cd $reporoot/bot/Bundlebot/nightly
./make_smvapps.sh

echo "*** bundling smokeview"

$reporoot/bot/Bundlebot/nightly/assemble_smvbundle.sh $smv_revision $basereporoot

uploaddir=$HOME/.bundle/bundles
if [ -e $uploaddir/${smv_revision}_${platform2}.sh ]; then
  echo smv bundle: $HOME/$uploaddir/${smv_revision}_${platform2}.sh created
else
  echo ***error: smv bundle: $HOME/$uploaddir/${smv_revision}_${platform2}.sh failed to be created
fi



if [ "$UPLOADBUNDLE" != "" ]; then
  echo "*** uploading smokeview bundle"

  FILELIST=`gh release view SMOKEVIEW_TEST  -R github.com/$GHOWNER/test_bundles | grep SMV |   grep -v FDS | grep $platform2 | awk '{print $2}'`
  for file in $FILELIST ; do
    gh release delete-asset SMOKEVIEW_TEST $file -R github.com/$GHOWNER/test_bundles -y
  done

  $reporoot/bot/Bundlebot/nightly/upload_smvbundle.sh $uploaddir ${smv_revision}_${platform2}.sh                $basereporoot/bot/Bundlebot/nightly $GHOWNER
  $reporoot/bot/Bundlebot/nightly/upload_smvbundle.sh $uploaddir ${smv_revision}_${platform2}_manifest.html     $basereporoot/bot/Bundlebot/nightly $GHOWNER

  echo "*** upload complete"
fi

