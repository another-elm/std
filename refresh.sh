#! /usr/bin/env bash

set -o errexit;
set -o nounset;

rm -vf "$1"/*.dat "$1"/doc*.json > /dev/null

