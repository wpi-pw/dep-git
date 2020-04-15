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
  filename="${file%.*}"
  # Split filename to name and version
  package=($(awk -F'-v' '{ for(i=1;i<=NF;i++) print $i }' <<< ${file%.zip}))

  # Git clone repo
  git clone --depth=1 git@bitbucket.org:$BITBUCKET_TEAM/${package[0]}.git
  # If repository not exist, ask to create
  [ ! -d "${PWD}/${package[0]}" ] && read -r -p "Repo not found, create new one?[y/N] " new_repo_approve
  # Request the password of bitbucket, required by API, or continue
  if [[ "$new_repo_approve" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    [ -z "$BITBUCKET_PASSWORD" ] && read -r -p "Please enter the bitbucket password: " BITBUCKET_PASSWORD
    [ -z "$BITBUCKET_PASSWORD" ] && continue
    user_data=$BITBUCKET_USER:$BITBUCKET_PASSWORD
    api_url="https://api.bitbucket.org/2.0/repositories/$BITBUCKET_TEAM/${package[0]}"
    api_json='{"name": "'${package[0]}'", "is_private": true, "project": {"key": "'$BITBUCKET_PROJECT'"}}'
    curl -X POST -s -u $user_data $api_url -H "Content-Type:application/json" -d $api_json 1>/dev/null
    git clone --depth=1 git@bitbucket.org:$BITBUCKET_TEAM/${package[0]}.git
    # If not created and cloned continue to next
    [ ! -d "${PWD}/${package[0]}" ] && continue
  fi

  # If not cloned  continue to next
  [ ! -d "${PWD}/${package[0]}" ] && continue

  # Clean cur version and unzip new version and move to the repo
  rm -rf ${PWD}/${package[0]}/*
  unzip -q ${PWD}/$entry -d ${PWD}/zip-tmp
  [ -d "${PWD}/zip-tmp/$filename" ] && mv ${PWD}/zip-tmp/$filename ${PWD}/zip-tmp/${package[0]}
  [ -d "${PWD}/zip-tmp/__MACOSX" ] && rm -rf ${PWD}/zip-tmp/__MACOSX
  [ -d "${PWD}/zip-tmp/${package[0]}" ] && repo_dir="/${package[0]}"
  mv ${PWD}/zip-tmp$repo_dir/* ${PWD}/${package[0]}
  rm -rf ${PWD}/zip-tmp

  # Setup git config
  cd ${PWD}/${package[0]}
  git config user.name $BITBUCKET_TEAM
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
