#!/bin/bash

# WPI Dep Git Push
# by DimaMinka (https://dima.mk)
# https://github.com/wpi-pw/app

# Parse the config.yml and declare vars
mapfile -t conf_array < <(yq r config.yml | grep -v '  .*' | sed -n -e '/^\([^ ]\([^:]\+\)\?\):/  s/:.*// p')
for i in "${!conf_array[@]}"; do
  declare "${conf_array[$i]}"="$(yq r config.yml ${conf_array[$i]})"
done

# Scan zip folder and loop
for entry in zip/*.zip
do
  # Clean file path
  file=${entry##*/}
  # Split filename to name and version
  package=($(awk -F'-v' '{ for(i=1;i<=NF;i++) print $i }' <<< ${file%.zip}))

  # Git clone repo
  git clone --depth=1 git@bitbucket.org:$BITBUCKET_USER/${package[0]}.git

  # If not cloned  continue to next
  [ ! -d "${PWD}/${package[0]}" ] && continue

  # Clean cur version and unzip new version and move to the repo
  rm -rf ${PWD}/${package[0]}/*
  unzip -q ${PWD}/$entry -d ${PWD}/zip-tmp
  [ -d "${PWD}/zip-tmp/__MACOSX" ] && rm -rf ${PWD}/zip-tmp/__MACOSX
  count_dirs=$(find zip-tmp/* -maxdepth 0 -type d | wc -l)
  [ "$count_dirs" == 1 ] && repo_dir="/${package[0]}"
  mv ${PWD}/zip-tmp$repo_dir/* ${PWD}/${package[0]}
  rm -rf ${PWD}/zip-tmp

  # Setup git config
  cd ${PWD}/${package[0]}
  git config user.name $BITBUCKET_USER
  git config user.email $BITBUCKET_EMAIL

  # Git commit and tag for new version
  git add .
  git commit -m v${package[1]}
  git push origin master
  git tag -a v${package[1]} -m v${package[1]}
  git push --tags

  # Clean current repo and zip
  cd ../
  rm -rf ${PWD}/${package[0]}
  rm ${PWD}/$entry
done
