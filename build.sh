#!/bin/bash

function run {
	cmd="$*"
	echo "$cmd"
	$cmd
}

DEBUG_BUILD_FLAGS=('-debug' '-o:none' '-vet-shadowing' '-vet-using-param' '-vet-using-stmt' '-vet-style' '-vet-semicolon' '-vet-tabs')
RELEASE_BUILD_FLAGS=('-disable-assert' '-o:speed' '-vet' '-vet-using-param' '-vet-using-stmt' '-vet-style' '-vet-semicolon' '-vet-tabs')
BUILD_FLAGS=("${DEBUG_BUILD_FLAGS[@]}")

# read args
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
	--release )
		BUILD_FLAGS=("${RELEASE_BUILD_FLAGS[@]}")
		;;
esac; shift; done
if [[ $1 == '--' ]]; then shift; fi

# compile
run odin build . "${BUILD_FLAGS[@]}"
