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

while getopts 'hm:o:' OPTION
do
case $OPTION  in
  h)
   echo Usage:
   echo ./BUILD_fds_manuals.sh -o owner -m email_address
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

./SetRepoRevTags.sh

echo FDS manuals will be built using:
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
echo "Make sure repos were cleaned and updated.
echo "Press any key to continue or <CTRL> c to abort."
echo "Type $0 -h for other options"
read val

cd ../../../Firebot
echo ./run_firebot.sh -f -q firebot $MAILTO -U -r test_bundles $OWNER
     ./run_firebot.sh -f -q firebot $MAILTO -U -r test_bundles $OWNER 
