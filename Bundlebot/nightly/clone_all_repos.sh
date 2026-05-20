#!/bin/bash
OUTDIR=$1
BUNDLETYPE=$2
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CURDIR=`pwd`
cd $SCRIPTDIR/../../..
REPOROOT=`pwd`
cd $SCRIPTDIR

if [ "$BUNDLETYPE" == "" ]; then
  BUNDLETYPE=master
fi

# ------------------- usage -----------------------------

function usage {
echo "Clone all repos using hash and tags in config.sh"
echo ""
echo "Options:"
echo "-h - display this message"
exit 0
}

while getopts 'h' OPTION
do
case $OPTION  in
  h)
   usage;
   ;;
esac
done
shift $(($OPTIND-1))

cd $REPOROOT/bot/Scripts

echo cloning cad
./setup_repos.sh -b -B $BUNDLETYPE-K cad >& $OUTDIR/clone_cad &
pid_cad=$!

echo cloning exp
./setup_repos.sh -b -B $BUNDLETYPE-K exp >& $OUTDIR/clone_exp &
pid_exp=$!

echo cloning fds
./setup_repos.sh -b -B $BUNDLETYPE-K fds >& $OUTDIR/clone_fds &
pid_fds=$!

echo cloning fig
./setup_repos.sh -b -B $BUNDLETYPE-K fig >& $OUTDIR/clone_fig &
pid_fig=$!

echo cloning out
./setup_repos.sh -b -B $BUNDLETYPE-K out >& $OUTDIR/clone_out &
pid_out=$!

echo cloning smv
./setup_repos.sh -b -B $BUNDLETYPE-K smv >& $OUTDIR/clone_smv &
pid_smv=$!

wait $pid_cad
echo "*** cad cloned"

wait $pid_exp
echo "*** exp cloned"

wait $pid_fds
echo "*** fds cloned"

wait $pid_fig
echo "*** fig cloned"

wait $pid_out
echo "*** out cloned"

wait $pid_smv
echo "*** smv cloned"