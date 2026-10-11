#!/bin/bash
# Check out and tag the revisions defined for the release bundle.
set -e

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BOTREPO="$( cd "$SCRIPTDIR/.." && pwd )"
FMROOT="$( cd "$BOTREPO/.." && pwd )"
source "$BOTREPO/Bundlebot/release/config.sh"

repos="cad exp fds fig out smv"
for repo in $repos
do
  TAG=
  HASH=
  case "$repo" in
    cad) TAG=$BUNDLE_CAD_TAG; HASH=$BUNDLE_CAD_HASH ;;
    exp) TAG=$BUNDLE_EXP_TAG; HASH=$BUNDLE_EXP_HASH ;;
    fds) TAG=$BUNDLE_FDS_TAG; HASH=$BUNDLE_FDS_HASH ;;
    fig) TAG=$BUNDLE_FIG_TAG; HASH=$BUNDLE_FIG_HASH ;;
    out) TAG=$BUNDLE_OUT_TAG; HASH=$BUNDLE_OUT_HASH ;;
    smv) TAG=$BUNDLE_SMV_TAG; HASH=$BUNDLE_SMV_HASH ;;
  esac
  repo_dir="$FMROOT/$repo"
  ERROR=
  if [[ "$TAG" == "" ]] || [[ "$HASH" == "" ]]; then
    echo "***Error: missing release tag or revision for $repo" >&2
    ERROR=1
  fi
  if [[ ! -d "$repo_dir" ]]; then
    echo "***Error: repository directory $repo_dir does not exist" >&2
    ERROR=1
  fi
  if [ "$ERROR" != "" ]; then
    exit 1
  fi
  (
    cd "$repo_dir"
    echo "----------------------------------------------"
    echo "repo: $repo"
    echo "git checkout -b release $HASH"
    git checkout -b release "$HASH"
    echo "git tag -a $TAG -m \"tag for $TAG\""
    git tag -a "$TAG" -m "tag for $TAG"
  )
done
