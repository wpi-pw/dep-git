#!/bin/bash

# WPI Dep Git Push
# by DimaMinka (https://dima.mk)
# https://github.com/wpi-pw/app

# Parse the config.yml and declare vars
mapfile -t conf_array < <(yq r config.yml | grep -v '  .*' | sed -n -e '/^\([^ ]\([^:]\+\)\?\):/  s/:.*// p')
for i in "${!conf_array[@]}"; do
  declare "${conf_array[$i]}"="$(yq r config.yml ${conf_array[$i]})"
done

# Prepare json data for bitbucket API
generate_post_data() {
  cat <<EOF
{
  "name": "$1",
  "is_private": true,
  "fork_policy": "no_forks",
  "language": "php",
  "project": {
    "key": "$2"
  }
}
EOF
}

# Scan zip folder and loop
for entry in zip/*.zip; do
  # Clean file path
  file=${entry##*/}
  filename="${file%.*}"
  # Split filename to package name and version
  package="$( cut -d '.' -f 1 <<< "${file%.zip}" )"
  version="$( cut -d '.' -f 2- <<< "${file%.zip}" )"

  # Lower case helper
  package=${package,,}
  # Dir helper
  repo_dir=""

  # Git clone repo
  git clone --depth=1 git@bitbucket.org:$BITBUCKET_TEAM/$package.git
  # If repository not exist, ask to create
  [ ! -d "${PWD}/$package" ] && read -r -p "Repo not found, create new one?[y/N] " new_repo_approve
  # Request the password of bitbucket, required by API, or continue
  if [[ "$new_repo_approve" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    [ -z "$BITBUCKET_PASSWORD" ] && read -r -p "Please enter the bitbucket password: " BITBUCKET_PASSWORD
    [ -z "$BITBUCKET_PASSWORD" ] && continue
    json_data=$(generate_post_data $package $BITBUCKET_PROJECT)
    user_data=$BITBUCKET_USER:$BITBUCKET_PASSWORD
    api_url="https://api.bitbucket.org/2.0/repositories/$BITBUCKET_TEAM/$package"
    curl -X POST -s -u $user_data $api_url -H "Content-Type:application/json" -d "$json_data" 1>/dev/null
    git clone --depth=1 git@bitbucket.org:$BITBUCKET_TEAM/$package.git
    # If not created and cloned continue to next
    [ ! -d "${PWD}/$package" ] && continue
  fi
  # If not cloned  continue to next
  [ ! -d "${PWD}/$package" ] && continue

  # Clean cur version and unzip new version and move to the repo
  rm -rf ${PWD}/$package/*
  unzip -q ${PWD}/$entry -d ${PWD}/zip-tmp
  [ -d "${PWD}/zip-tmp/$filename" ] && mv ${PWD}/zip-tmp/$filename ${PWD}/zip-tmp/$package
  [ -d "${PWD}/zip-tmp/__MACOSX" ] && rm -rf ${PWD}/zip-tmp/__MACOSX
  [ -d "${PWD}/zip-tmp/$package" ] && repo_dir="/$package"
  mv ${PWD}/zip-tmp$repo_dir/* ${PWD}/$package
  rm -rf ${PWD}/zip-tmp

  # Setup git config
  cd ${PWD}/$package
  git config user.name $BITBUCKET_TEAM
  git config user.email $BITBUCKET_EMAIL

  # Git commit and tag for new version
  git add .
  git commit -m v$version
  git push origin master
  git tag -a v$version -m v$version
  git push --tags

  # Clean current repo and zip
  cd ../
  rm -rf ${PWD}/$package
  rm ${PWD}/$entry
done
