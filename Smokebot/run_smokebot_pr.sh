#!/bin/bash
PRNUM=$1
MAILTO=$2

CURDIR=`pwd`
cd ../..
GITROOT=`pwd`
cd smv
SMVREPO=`pwd`
cd $GITROOT/bot
BOTREPO=`pwd`

cd $BOTREPO/Scripts

echo "cleaning repos"
./clean_repos.sh >& /dev/null

echo "updating repos"
./update_repos.sh -ma >& /dev/null

echo "creating branch for smokeview pull request: $PRNUM"
./test_pull.sh ${PRNUM}

cd $BOTREPO/Smokebot

echo ./run_smokebot.sh  -b -c $MAILTO

