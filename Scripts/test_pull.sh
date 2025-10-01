#!/bin/bash
id=$1
repo=$2
cleanupdate=$3

CURDIR=`pwd`
if [ "$repo" == "" ]; then
  repo=smv
fi
if [ "$cleanupdate" != "" ]; then
  echo "cleaning repos"
  ./clean_repos.sh     >& /dev/null
  echo "updating repos"
  ./update_repos.sh -m >& /dev/null
fi

cd $CURDIR/../../$repo

git fetch firemodels pull/$id/head:PR_$id
git branch -a
git checkout PR_$id
