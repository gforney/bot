#!/bin/bash
# build a release bundle using revision and tags defined in config.sh .
source ../fds/config.sh

./BuildSmvNightly.sh -R -U
