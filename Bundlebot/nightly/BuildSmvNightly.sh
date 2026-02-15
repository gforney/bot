#!/bin/bash

#---------------------------------------------
#                   GET_TIME
#---------------------------------------------

GET_TIME(){
  echo $(date +"%s")
}

#---------------------------------------------
#                   GET_DURATION
#---------------------------------------------

GET_DURATION(){
  local time_before=$1
  local time_after=$2
  local __var=$3

  DELTA_TIME=`echo $(($time_after-$time_before))`
  TIME_H=`echo $(($DELTA_TIME / 3600 ))`
  TIME_M=`echo $((($DELTA_TIME % 3600 ) / 60))`
  TIME_S=`echo $(($DELTA_TIME % 60 ))`
  if (( "$DELTA_TIME" >= 3600 )) ; then
    DIFF_TIME="${TIME_H}h ${TIME_M}m ${TIME_S}s"
  else
    if (( "$DELTA_TIME" >= 60 )) ; then
      DIFF_TIME="${TIME_M}m ${TIME_S}s"
    else
      DIFF_TIME="${TIME_S}s"
    fi
  fi
  eval ${__var}_DIFF="'${DIFF_TIME}'"
  eval ${__var}_DELTA="'${DELTA_TIME}'"
}

#---------------------------------------------
#                   USAGE
#---------------------------------------------

function USAGE {
echo ""
echo "BUILDSmvNightly.sh usage"
echo ""
echo "Options:"
echo "-C - use current revision"
echo "-h - display this message"
echo "-k - kill the BuildSmvNightly.sh process and all of its child processes"
echo "-n - do not scan bundle"
echo "-u - upload bundle file to GitHub owner: `whoami`"
echo "-U - upload bundle file to GitHub owner: $GHOWNER"
exit 0
}

#-------------------- start of script ---------------------------------

TIME_beg=`GET_TIME`
curdir=`pwd`

S_HASH=
S_REVISION=

#S_HASH=2f257722a
#S_REVISION=SMV-6.10.5-249

UPLOADBUNDLE=
export BUILDING_release=
OUTPUT_USAGE=
USE_CURRENT=
PIDFILE=$curdir/smvbundle.pid
scan_bundle=1

#*** parse parameters

while getopts 'ChknuUR' OPTION
do
case $OPTION  in
  C)
   USE_CURRENT=1
   ;;
  h)
   OUTPUT_USAGE=1
   ;;
  k)
   if [ -e $PIDFILE ]; then
     PID=`head -1 $PIDFILE`
     kill -9 -- -$PID
     rm -f $PIDFILE
   else
     echo ***warning pid file $PIDFILE does not exist
   fi
   exit
   ;;
  n)
   scan_bundle=0
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

echo $$ > $PIDFILE

if [ "$BUILDING_release" == "" ]; then
  if [ "$GHOWNER" == "" ]; then
    GHOWNER=firemodels
  fi
else
  git tag -a $BUNDLE_SMV_TAG -m "tag for smokeview release" >> $outdir/stage2_clone 2>&1
  GHOWNER=`whoami`
fi
if [ "$OUTPUT_USAGE" != "" ]; then
  USAGE
  exit
fi

#*** determine platform script is running on

platform=linux
LABEL=lnx
comp=intel
if [ "`uname`" == "Darwin" ] ; then
  platform="osx"
  LABEL="osx_intel"
  if [ "`uname -m`" == "arm64" ] ; then
    LABEL="osx_arm"
  fi
  comp=gnu
fi

cd ../../..
reporoot=`pwd`
basereporoot=`basename $reporoot`

if [ -d $reporoot/smv ]; then
  cd $reporoot/smv
  echo "*** updating smv repo"
  git remote update           > /dev/null 2>&1 
  git merge firemodels/master > /dev/null 2>&1
  git merge origin/master     > /dev/null 2>&1
else
  echo "***warning: smv repo does not exist"
fi

echo "*** get smv repo revision"
if [ "$BUILDING_release" == "" ]; then
  cd $reporoot/bot/Bundlebot/nightly/output
  outdir=`pwd`
  cd $reporoot/bot/Bundlebot/nightly
  ./get_hash_revisions.sh $outdir $USE_CURRENT >& $outdir/stage1_hash
  smv_hash=`head -1 $outdir/SMV_HASH`
else
  ERROR=
  if [ "$BUNDLE_SMV_HASH" == "" ]; then
    echo "***error: environment variable BUNDLE_SMV_HASH not defined"
    ERROR=1
  fi
  if [ "$BUNDLE_SMV_TAG" == "" ]; then
    echo "***error: environment variable BUNDLE_SMV_TAG not defined"
    ERROR=1
  fi
  if [ "$ERROR" != "" ]; then
    exit
  fi
  cd $reporoot/bot/Bundlebot/release/output
  outdir=`pwd`
  smv_hash=$BUNDLE_SMV_HASH
fi

#*** cloning smv repo

cd $reporoot/bot/Bundlebot/nightly
echo "*** cloning smv repo"
./clone_smvrepo.sh $smv_hash $BUILDING_release >& $outdir/stage2_clone

#*** get branch names

cd $reporoot/bot
BOTBRANCH=`git branch --show-current`
BOTREVISION=`git describe`
cd $reporoot/smv
SMVBRANCH=`git branch --show-current`
SMVREVISION=`git describe`
if [ "$BUILDING_release" == "" ]; then
  BUNDLETYPE=nightly
else
  BUNDLETYPE=release
fi

echo ""
echo "------------------------------------------------------------"
echo "               bundle type: $BUNDLETYPE"
echo "              bot revision: $BOTREVISION/$BOTBRANCH"
echo "              smv revision: $SMVREVISION/$SMVBRANCH"
echo "------------------------------------------------------------"
echo ""

cd $reporoot/smv
if [ "$BUILDING_release" == "" ]; then
  smv_revision=`git describe --abbrev=7 --dirty --long`
else
  smv_revision=$BUNDLE_SMV_TAG
fi

#*** build apps

cd $reporoot/bot/Bundlebot/nightly
./make_smvapps.sh

#*** make bundle

echo "*** bundling smokeview"
$reporoot/bot/Bundlebot/nightly/assemble_smvbundle.sh $smv_revision $basereporoot $LABEL $scan_bundle

uploaddir=$HOME/.bundle/bundles
if [ ! -e $uploaddir/${smv_revision}_${LABEL}.sh ]; then
  echo "***error: smv bundle: $HOME/$uploaddir/${smv_revision}_${LABEL}.sh failed to be created"
fi

#*** upload bundle

if [ "$UPLOADBUNDLE" != "" ]; then
  echo "*** uploading smokeview bundle"

  FILELIST=`gh release view SMOKEVIEW_TEST  -R github.com/$GHOWNER/test_bundles | grep SMV |   grep -v FDS | grep $LABEL | awk '{print $2}'`
  for file in $FILELIST ; do
    gh release delete-asset SMOKEVIEW_TEST $file -R github.com/$GHOWNER/test_bundles -y
  done

  $reporoot/bot/Bundlebot/nightly/upload_smvbundle.sh $uploaddir ${smv_revision}_${LABEL}.sh                $basereporoot/bot/Bundlebot/nightly $GHOWNER
  $reporoot/bot/Bundlebot/nightly/upload_smvbundle.sh $uploaddir ${smv_revision}_${LABEL}_manifest.html     $basereporoot/bot/Bundlebot/nightly $GHOWNER

  echo "*** upload complete"
fi
rm -f $PIDFILE
TIME_end=`GET_TIME`
GET_DURATION $TIME_beg $TIME_end TIME
echo Time: $TIME_diff
