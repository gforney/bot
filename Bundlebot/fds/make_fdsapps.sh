#!/bin/bash

# -------------------------------------------------------------

BUILDFDSUTIL()
{
  prog=$1
  builddir=$2

  cd $REPOROOT/fds/Utilities/$prog/$builddir
  ./make_${prog}.sh bot >> $outputdir/compile_$prog.log 2>&1
}

# -------------------------------------------------------------

CHECK_BUILDFDSUTIL()
{
  prog=$1
  builddir=$2

  if [ ! -e $REPOROOT/fds/Utilities/$prog/$builddir/${prog}_$builddir ]; then
    echo "***error: The program ${prog}_$builddir failed to build"
    echo "***error: The program ${prog}_$builddir failed to build"   >> $errorlog 2>&1
  else
    echo "*** ${prog}_$builddir built"
    cp $REPOROOT/fds/Utilities/$prog/$builddir/${prog}_$builddir  $CURDIR/apps/$prog
  fi
}

# -------------------------------------------------------------

CHECK_BUILDTESTMPI()
{
  if [ ! -e $REPOROOT/fds/Utilities/test_mpi/${mpitype}_${BUNDLE_FDSCOMPILER}_$platform/test_mpi ]; then
    echo "***error: The program test_mpi failed to build"
    echo "***error: The program test_mpi failed to build"  >> $errorlog 2>&1
  else
    echo "*** test_mpi built"
    cp $REPOROOT/fds/Utilities/test_mpi/${mpitype}_${BUNDLE_FDSCOMPILER}_$platform/test_mpi  $CURDIR/apps/test_mpi
  fi
}
# -------------------------------------------------------------

BUILDFDS()
{
  cd $REPOROOT/fds/Build/${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}
  ./make_fds.sh bot  >> $outputdir/compile_fds.log 2>&1
}

BUILDFDSOPENMP()
{
  cd $REPOROOT/fds/Build/${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp
  cp make_fds.sh make_fds_openmp.sh
  ./make_fds_openmp.sh bot >> $outputdir/compile_fdsopenmp.log 2>&1
}

# -------------------------------------------------------------

CHECK_BUILDFDS()
{
  if [ ! -e $REPOROOT/fds/Build/${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}/fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform} ]; then
    echo "***error: The program fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform} failed to build"
    echo "***error: The program fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform} failed to build"  >> $errorlog 2>&1
  else
    echo "*** fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform} built"
    cp $REPOROOT/fds/Build/${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}/fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform} $CURDIR/apps/fds
  fi
}

# -------------------------------------------------------------

CHECK_BUILDFDSOPENMP()
{
  if [ ! -e $REPOROOT/fds/Build/${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp/fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp ]; then
    echo "***error: The program fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp failed to build"
    echo "***error: The program fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp failed to build"   >> $errorlog 2>&1
  else
    echo "*** fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp built"
    cp  $REPOROOT/fds/Build/${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp/fds_${mpitype}_${BUNDLE_FDSCOMPILER}_${platform}_openmp $CURDIR/apps/fds_openmp
  fi
}

#--------------------- start of script -------------------------------

if [ "$BUNDLE_FDSCOMPILER" == "" ]; then
  BUNDLE_FDSCOMPILER=intel
fi
if [ "${BUNDLE_MPITYPE}" == "" ]; then
  BUNDLE_MPITYPE=INTELMPI
fi
if [ "${BUNDLE_MPITYPE}" == "INTELMPI" ]; then
  mpitype=impi
else
  mpitype=ompi
fi
export FDS_BUILD_TARGET=intel
platform=linux
if [ "`uname`" == "Darwin" ] ; then
  platform="osx"
  export FDS_BUILD_TARGET=osx
fi

CURDIR=`pwd`

outputdir=$CURDIR/output
cleanlog=$CURDIR/output/fdsclean.log
errorlog=$CURDIR/output/fdserror.log

echo > $cleanlog
echo > $errorlog

cd ../../..
REPOROOT=`pwd`

cd $REPOROOT/fds/Utilities
echo "*** cleaning $REPOROOT/fds/Utilities"
git clean -dxf  >> $cleanlog 2>&1 

cd $REPOROOT/fds/Build
echo "*** cleaning $REPOROOT/fds/Build"
git clean -dxf  >> $cleanlog 2>&1 

cd $CURDIR

echo "*** building test_mpi"
BUILDFDSUTIL test_mpi  ${mpitype}_${BUNDLE_FDSCOMPILER}_$platform    &
pid_test_mpi=$!

echo "*** building fds2ascii"
BUILDFDSUTIL fds2ascii ${BUNDLE_FDSCOMPILER}_$platform               &
pid_fds2ascii=$!

source $REPOROOT/fds/Build/Scripts/set_compilers.sh >& /dev/null
# Set FIREMODELS environment variable if it is not already exists.
cd $REPOROOT/fds/Build/Scripts
if [ -z "${FIREMODELS}" ]; then
  export FIREMODELS="$(readlink -f "$(pwd)/../../../")"
fi

echo "*** building hypre"
source ../Scripts/HYPRE/build_hypre.sh confmake.sh true   > $outputdir/compile_hypre.log 2>&1    &
pid_hypre=$!

echo "*** building sundials"
source ../Scripts/SUNDIALS/build_sundials.sh confmake.sh true > $outputdir/sundials_hypre.log 2>&1    &
pid_sundials=$!

wait $pid_hypre
echo "*** hypre built"

wait $pid_sundials
echo "*** sundials built"

echo "*** building fds"
BUILDFDS                                                      &
pid_fds=$!

if [ "${BUNDLE_FDSCOMPILER}" == "intel" ]; then
  echo "*** building fds openmp"
  BUILDFDSOPENMP
  CHECK_BUILDFDSOPENMP
fi

wait $pid_fds
CHECK_BUILDFDS

wait $pid_fds2ascii
CHECK_BUILDFDSUTIL    fds2ascii ${BUNDLE_FDSCOMPILER}_$platform

wait $pid_test_mpi
CHECK_BUILDTESTMPI  

cd $CURDIR
