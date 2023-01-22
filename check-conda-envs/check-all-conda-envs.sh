#!/bin/bash
#
# Copyright 2023, Peter Menzel
#
# Usage:
# Arguments are one or more folders containing conda environment files in YAML format
#

function log {
	echo -e "[$(date)]\e[34m $1\e[0m"
}
function info {
	echo -e "[$(date)]\e[32m $1\e[0m"
}
function error {
	echo -e "[$(date)]\e[31m ERROR: $1\e[0m"
}
function warn {
	echo -e "[$(date)]\e[33m WARNING: $1\e[0m"
}

log "-----------------------------------------------------------------"
if [ -n "$GITHUB_ACTIONS" ]
then
	echo '::group::GH Actions Environment'
	env | grep -E "GITHUB|RUNNER" | sort
	echo '::endgroup::'
	echo '::group::conda info'
	conda info
	echo '::endgroup::'
	HTML="--html"
fi

SCRIPTDIR=${BASH_SOURCE%/*}
log "SCRIPTDIR=$SCRIPTDIR"

# make list of *.yaml/*.yml files in either the specified target folder(s),
# or the repo when running as GH Action, or the current directory
rm -f filelist.txt
if [ -n "$1" ]
then
	while [ "$#" -gt 0 ]
	do
		if [ -d "$1" ]
		then
			log "TARGET_FOLDER=$1"
			find "$1" -name "*.yaml" >> filelist.txt
			find "$1" -name "*.yml" >> filelist.txt
		else
			warn "Not a directory: $1"
		fi
		shift
	done
else
	TARGET_FOLDER=${GITHUB_WORKSPACE:-.}
	log "TARGET_FOLDER=$TARGET_FOLDER"
	find "$TARGET_FOLDER" -name "*.yaml" > filelist.txt
	find "$TARGET_FOLDER" -name "*.yml" >> filelist.txt
fi

OUTPUT=${GITHUB_STEP_SUMMARY:-/dev/stdout}
log "OUTPUT=${OUTPUT}"

# ---------------------------------------------------------------------------------------------------------

# fail on errors
set -Eeo pipefail

log "-----------------------------------------------------------------"

# run check-for-upgraded-pkgs.pl for each file and remember exit code
while read -r fname; do
	log "Testing file $fname"
	if [ -n "$GITHUB_ACTIONS" ]
	then
		echo >> "${OUTPUT}"
		echo "### $fname"  >> "${OUTPUT}"
		echo >> "${OUTPUT}"
	fi
	if ! "$SCRIPTDIR/check-yaml-for-upgradable-pkgs.pl" ${HTML+"$HTML"} "$fname" >>"${OUTPUT}" # https://wiki.bash-hackers.org/syntax/pe#use_an_alternate_value
	then
		error "Error in file $fname"
		ERR=1
	fi
	echo >> "${OUTPUT}"
done < filelist.txt


log "-----------------------------------------------------------------"

if [ "$ERR" ]
then
	error "Errors were found!"
	exit 1
fi

