#!/bin/bash

#---------------------------------------------
#                   usage
#---------------------------------------------

function usage {
echo ""
echo "BuildNightly.sh usage"
echo ""
echo "This script builds FDS and Smokeview apps and generates a bundle using either the"
echo "specified fds and smv repo revisions or revisions from the latest firebot pass."
echo ""
echo "Options:"
echo "-B - install bundle after it is built"
echo "-c - bundle without warning about cloning/erasing fds and smv repos"
echo "-f - force this script to run"
echo "-h - display this message"
echo "-I - only build installer, assume repos are already cloned and apps are already built"
echo "-L - build apps using latest revision"
if [ "$MAILTO" != "" ]; then
  echo "-m mailto - email address [default: $MAILTO]"
else
  echo "-m mailto - email address"
fi
echo "-o - specify GH_OWNER when building a bundle. [default: $GH_OWNER]"
echo "-r - specify GH_REPO when building a bundle. [default: $GH_REPO]"
echo "-R branch - clone repos using name branch {default: $BRANCH]"
echo "-r - create a release bundle (same as -R branc)"
echo "-U - upload bundle file to GitHub."
exit 0
}

# -------------------- is_file_installed -------------------

IS_PROGRAM_INSTALLED()
{
  program=$1
  notfound=`$program -help 2>&1 | tail -1 | grep "not found" | wc -l`
  if [ $notfound -eq 0 ] ; then
    echo 1
  else
    echo 0
  fi
  exit
}

#-------------------- start of script ---------------------------------

commands=$0
DIR=$(dirname "${commands}")
cd $DIR
DIR=`pwd`
SCRIPTDIR=$DIR

cd ../../..
GITROOT=`pwd`

if [ "`uname`" == "Darwin" ] ; then
  platform=osx
else
  platform=lnx
fi

UPLOADBUNDLE=

#define mpi environment used to build bundle
mpirun_status=`IS_PROGRAM_INSTALLED mpirun`
if [ $mpirun_status -eq 0 ]; then
  echo ***error: mpi environment not defined
  exit
fi

IS_INTEL=`mpirun --version | head -1 | grep Intel| wc -l`
echo IS_INTEL=$IS_INTEL
if [[ $IS_INTEL -eq 0 ]] && [[ "$platform" == "osx" ]]; then
    export MPI_TYPE="OPENMPI"
elif [[ $IS_INTEL -ne 0 ]] && [[ "$platform" == "lnx" ]]; then
    export MPI_TYPE="INTELMPI"
else
  if [ "$platform" == "osx"  ]; then
    echo "***error: Intel mpi not supported on a Mac"
  else
    echo "***error: OpenMPI not supported on Linux"
  fi
  exit
fi

OPENMPI_BIN=
INTELMPI_BIN=
if [ "$MPI_TYPE" == "INTELMPI" ]; then
  export INTELMPI_BIN=`dirname "$(which mpirun)"`  
fi
if [ "$MPI_TYPE" == "OPENMPI" ]; then
  export OPENMPI_BIN=`dirname "$(which mpirun)"`
fi

#define BUNDLE_MAILTO in .bashrc
if [ "$BUNDLE_MAILTO" != "" ]; then
  MAILTO=$BUNDLE_MAILTO
fi

cd $DIR/output
outputdir=`pwd`
git clean -dxf

cd $DIR

LOCKFILE=$HOME/.bundle/lock

MAILTO=
if [ "$BUNDLE_EMAIL" != "" ]; then
  MAILTO=$BUNDLE_EMAIL
fi

PROCEED=
FORCE=
RELEASE=
BRANCH=nightly
FDS_TAG=
SMV_TAG=
LATEST=
INSTALL=
export TEST_VIRUS=
USE_CURRENT=
ONLY_INSTALLER=

while getopts 'BcCfhILm:o:r:R:TU' OPTION
do
case $OPTION  in
  B)
   INSTALL="-B"
   ;;
  c)
   PROCEED=1
   ;;
  C)
   USE_CURRENT=1
   ;;
  f)
   FORCE="-f"
   ;;
  h)
   usage
   ;;
  I)
   ONLY_INSTALLER=1
   ;;
  L)
   LATEST=1
   ;;
  m)
   MAILTO="$OPTARG"
   ;;
  o)
   export GH_OWNER="$OPTARG"
   ;;
  r)
   export GH_REPO="$OPTARG"
   ;;
  R)
   BRANCH="$OPTARG"
   ;;
  T)
   TEST_VIRUS=1
   ;;
  U)
   UPLOADBUNDLE=1
   ;;
esac
done
shift $(($OPTIND-1))

if [ "$BRANCH" == "nightly" ]; then
  FDS_TAG=
  SMV_TAG=
  if [ "$USE_CURRENT" == "" ]; then
    $GITROOT/bot/Firebot/getGHfile.sh FDS_INFO.txt
  else
    $SCRIPTDIR/make_fdsinfo.sh        FDS_INFO.txt
  fi
  FDS_HASH=`grep FDS_HASH  FDS_INFO.txt | awk '{print $2}'`
  SMV_HASH=`grep SMV_HASH  FDS_INFO.txt | awk '{print $2}'`
  FDS_REVISION=`grep FDS_REVISION  FDS_INFO.txt | awk '{print $2}'`
  SMV_REVISION=`grep SMV_REVISION  FDS_INFO.txt | awk '{print $2}'`
fi

# email address
MAILTO_ARG=$MAILTO
if [ "$MAILTO" != "" ]; then
  MAILTO="-m $MAILTO"
fi

echo ""
echo "------------------------------------------------------------"
echo "          Firebot branch: $BRANCH"
if [ "$INTELMPI_BIN" != "" ]; then
  echo "   Intel mpi bin directory: $INTELMPI_BIN"
  if [ -e $INTELMPI_BIN/mpirun ]; then
    echo "         Intel mpi version: `$INTELMPI_BIN/mpirun -version | head -1`"
  fi
fi
if [ "$OPENMPI_BIN" != "" ]; then
  echo "   Openmpi bin directory: $OPENMPI_BIN"
  if [ -e $OPENMPI_BIN/mpirun ]; then
    echo "         Openmpi version: `$OPENMPI_BIN/mpirun -V | head -1`"
  fi
fi
if [ "$MAILTO" != "" ]; then
  echo "                     EMAIL: $MAILTO_ARG"
fi
echo "------------------------------------------------------------"
echo ""
exit

if [ -e $LOCKFILE ]; then
  if [ "$FORCE" == "" ]; then
    echo "$0 already running."
    echo "If this is not the case, rerun using the -f option"
    exit
  fi
fi
touch $LOCKFILE

curdir=`pwd`

if [[ "$PROCEED" == "" ]] && [[ "$USE_CURRENT" ]]; then
  echo ""
  echo "------------------------------------------------------------"
  echo "------------------------------------------------------------"
  echo "You are about to erase and then clone the fds and smv repos."
  echo "Press any key to continue or <CTRL> c to abort."
  echo "To avoid this warning, use the -c option on the command line"
  echo "------------------------------------------------------------"
  echo "------------------------------------------------------------"
  read val
fi

#*** update webpages repos
if [[ -d $GITROOT/webpages ]] && [[ "$ONLY_INSTALLER" == "" ]]; then
  echo updating webpages repo
  cd $GITROOT/webpages
  get fetch origin              > $outputdir/update_webpages 2&>1
  git merge origin/nist-pages  >> $outputdir/update_webpages 2&>1
fi


if [ "$ONLY_INSTALLER" == "" ]; then
# clone 3rd party repos
  cd $curdir/../../Scripts
  echo cloning hypre
  ./setup_repos.sh -K hypre > $outputdir/clone_hypre 2&>1 &
  pid_clonehypre=$!

  echo cloning sundials
  ./setup_repos.sh -K sundials > $outputdir/clone_sundials 2&>1 &
  pid_clonesundials=$!

  cd $curdir
  pid_clonefds=
  pid_clonesmv=
  pid_cloneall=
  if [ "$BRANCH" == "nightly" ]; then
    if [ "$USE_CURRENT" == "" ]; then
# a nightly bundle - clone fds and smv repos
      echo cloning fds
      ./clone_repo.sh -F -N -r $FDS_HASH > $outputdir/clone_fds 2&>1 &
      pid_clonefds=$!

      echo cloning smv
      ./clone_repo.sh -S -N -r $SMV_HASH > $outputdir/clone_smv 2&>1 &
      pid_clonesmv=$!
    fi
  else
#a release bundle - clone all repos except for bot
    echo cloning all repos 
    ./clone_all_repos.sh  $outputdir > $outputdir/clone_all 2&>1 &
    pid_cloneall=$!
  fi

  wait $pid_clonehypre
  echo hypre cloned

  wait $pid_clonesundials
  echo sundials cloned

  if [ "$pid_clonefds" != "" ]; then
    wait $pid_clonefds
    echo fds cloned

  fi
  if [ "$pid_clonesmv" != "" ]; then
    wait $pid_clonesmv
    echo sundials cloned
  fi
  if [ "$pid_cloneall" != "" ]; then
    wait $pid_cloneall
    echo all repos clone complete
  fi

  ./make_fdsapps.sh &
  pid_fdsapps=$1

  ./make_smvapps.sh &
  pid_smvapps=$!

  wait $pid_fdsapps
  wait $pid_smvapps
fi

if [ "$BRANCH" != "nightly" ]; then
  FDS_TAG="-X $BUNDLE_FDS_TAG"
  SMV_TAG="-Y $BUNDLE_SMV_TAG"
fi

echo $FDS_HASH     > $GITROOT/bot/Bundlebot/nightly/apps/FDS_HASH
echo $SMV_HASH     > $GITROOT/bot/Bundlebot/nightly/apps/SMV_HASH
echo $FDS_REVISION > $GITROOT/bot/Bundlebot/nightly/apps/FDS_REVISION
echo $SMV_REVISION > $GITROOT/bot/Bundlebot/nightly/apps/SMV_REVISION

#*** generate bundle
cd $curdir

export NOPAUSE=1

if [ "$BUILDING_release" == "1" ]; then
  releasetype="release"
  GHOWNER=`whoami`
else
  releasetype="nightly"
  GHOWNER=firemodels
fi

#run time libraries are located in
#  $HOME/.bundle/BUNDLE/MPI

bundle_dir=$HOME/.bundle/bundles

if [ "$FDS_TAG" != "" ]; then
  FDS_REVISION=$FDS_TAG
fi
if [ "$SMV_TAG" != "" ]; then
  SMV_REVISION=$SMV_TAG
fi

# prevent more than one instance of this script from running at the same time

LOCK_FILE=$HOME/.bundle/assemble_bundle_lock
if [ "$FORCE" == "" ]; then
  if [ -e $LOCK_FILE ]; then
    echo "***error: another instance of $0 is running."
    echo "          If this is not the case, re-run after removing"
    echo "          the lock file: $LOCKFILE"
    exit 1
  fi
fi
touch $LOCK_FILE

# determine platform script is running on

if [ "$BRANCH" == "release" ]; then
  BUNDLE_PREFIX=
  BUNDLE_PREFIX_FILE=
  BRANCHDIR=$BRANCH
  UPLOAD_DIR="bundle_test"
else
  BUNDLE_PREFIX="nightly"
  BUNDLE_PREFIX_FILE=${BUNDLE_PREFIX}_
  BRANCHDIR=
  UPLOAD_DIR=
fi

return_code=0
error_log=$SCRIPTDIR/output/error_nightly.log
./copy_pubs.sh fds $releasetype $SCRIPTDIR/pubs $GHOWNER $error_log || return_code=1
./copy_pubs.sh smv $releasetype $SCRIPTDIR/pubs $GHOWNER $error_log || return_code=1

if [ "$return_code" == "1" ]; then
  cat $error_log
  echo ""
  echo "bundle generation aborted"
  rm -f $LOCK_FILE
  exit 1
fi

# get fds and smv repo revision used to build apps

FDSREV=$FDS_REVISION
if [ "$FDS_REVISION" == "" ]; then
  if [ -e $SCRIPTDIR/apps/FDS_REVISION ]; then
    FDSREV=`cat $SCRIPTDIR/apps/FDS_REVISION`
  else
    FDSREV=fdstest
  fi
fi

SMVREV=$SMV_REVISION
if [ "$SMV_REVISION" == "" ]; then
  if [ -e $SCRIPTDIR/apps/SMV_REVISION ]; then
    SMVREV=`cat $SCRIPTDIR/apps/SMV_REVISION`
  else
    SMVREV=smvtest
  fi
fi

cd ../../..
REPO_ROOT=`pwd`
cd $SCRIPTDIR
installer_base=${FDSREV}_${SMVREV}
installer_base_platform=${installer_base}_${BUNDLE_PREFIX_FILE}$platform
csvlog=${installer_base_platform}.csv
htmllog=${installer_base_platform}_manifest.html

cd $SCRIPTDIR
echo ""
echo -n  "***Building installer"
./assemble_bundle.sh $FDSREV $SMVREV $BUNDLE_PREFIX
assemble_bundle_status=$?
echo " - complete"
  
echo
echo ***Virus scan summary
if [ -e $outputdir/$csvlog ]; then
  grep -v OK$ $outputdir/$csvlog | grep -v ^$ | grep -v SUMMARY
else
  echo virus scanner not available, bundle was not scanned
fi

if [[ "$UPLOADBUNDLE" == "1" ]]; then
  if [[ $assemble_bundle_status -eq 0 ]]; then
    echo ""
    echo "uploading installer"
    
    FILELIST=`gh release view FDS_TEST  -R github.com/$GHOWNER/test_bundles | grep SMV | grep FDS | grep $platform | awk '{print $2}'`
    for file in $FILELIST ; do
      gh release delete-asset FDS_TEST $file -R github.com/$GHOWNER/test_bundles -y
    done

    echo gh release upload FDS_TEST $bundle_dir/${installer_base_platform}.sh -R github.com/$GHOWNER/test_bundles  --clobber
         gh release upload FDS_TEST $bundle_dir/${installer_base_platform}.sh -R github.com/$GHOWNER/test_bundles  --clobber
    if [ -e $outputdir/$htmllog ]; then
      echo gh release upload FDS_TEST $outputdir/$htmllog                       -R github.com/$GHOWNER/test_bundles  --clobber
           gh release upload FDS_TEST $outputdir/$htmllog                       -R github.com/$GHOWNER/test_bundles  --clobber
    fi
    if [ "$platform" == "lnx" ]; then
      cd $REPO_ROOT/fds
      FDS_SHORT_HASH=`git rev-parse --short HEAD`
      cd $SCRIPTDIR
      ./setreleasetitle.sh fds $FDS_SHORT_HASH
    fi
  else
    echo ***error: virus detected in bundle, bundle not uploaded
  fi
fi
LATEST=$bundle_dir/FDS_SMV_latest_$platform.sh
BUNDLEBASE=$bundle_dir/${installer_base_platform}
if [ -e ${BUNDLEBASE}.sh ]; then
  rm -f  $LATEST
  ln -s ${BUNDLEBASE}.sh $LATEST
fi
cp $REPO_ROOT/bot/Bundlebot/nightly/autoinstall.txt $bundle_dir/.
#don't remove bundle directory
if [ "$INSTALL" != "" ]; then
  cd $bundle_dir
  cat autoinstall.txt | bash $LATEST >& $HOME/.bundle/bundle_lnx_nightly_install.log
fi
rm -f $LOCK_FILE

rm $LOCKFILE
