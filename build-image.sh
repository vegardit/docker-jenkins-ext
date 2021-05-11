#!/usr/bin/env bash
#
# Copyright 2020 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-jenkins-ext
#

set -eu

#################################################
# execute script with bash if loaded with other shell interpreter
#################################################
if [ -z "${BASH_VERSINFO:-}" ]; then /usr/bin/env bash "$0" "$@"; exit; fi

set -o pipefail

trap 'echo >&2 "$(date +%H:%M:%S) Error - exited with status $? at line $LINENO:"; pr -tn $0 | tail -n+$((LINENO - 3)) | head -n7' ERR


#################################################
# specify target docker registry/repo
#################################################
docker_registry=${DOCKER_REGISTRY:-docker.io}
image_repo=${DOCKER_REPO:-vegardit/jenkins-ext}
base_image_name=${DOCKER_BASE_IMAGE:-jenkins/jenkins:lts-slim}
base_image_tag=${base_image_name#*:}
image_name=$image_repo:$base_image_tag


#################################################
# determine directory of current script
#################################################
project_root=$(readlink -e $(dirname "${BASH_SOURCE[0]}"))


#################################################
# ensure Linux new line chars
#################################################
# env -i PATH="$PATH" -> workaround for "find: The environment is too large for exec()"
env -i PATH="$PATH" find "$project_root/image" -type f -exec dos2unix {} \;


#################################################
# calculate BASE_LAYER_CACHE_KEY
#################################################
# using the current date, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day
base_layer_cache_key=$(date +%Y%m%d)


#################################################
# build the image
#################################################
echo "Building docker image [$image_name]..."
if [[ $OSTYPE == "cygwin" || $OSTYPE == "msys" ]]; then
   project_root=$(cygpath -w "$project_root")
fi

docker build "$project_root/image" \
   --pull \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY=$base_layer_cache_key \
   --build-arg BASE_IMAGE=$base_image_name \
   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d @$(git log -1 --format='%at') --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   -t $image_name \
   "$@"


#################################################
# perform security audit using https://github.com/aquasecurity/trivy
#################################################
if [[ $OSTYPE != cygwin ]] && [[ $OSTYPE != msys ]]; then
   trivy_cache_dir="${TRIVY_CACHE_DIR:-$HOME/.trivy/cache}"
   trivy_cache_dir="${trivy_cache_dir/#\~/$HOME}"
   mkdir -p "$trivy_cache_dir"

   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "$trivy_cache_dir:/root/.cache/" \
      aquasec/trivy --no-progress \
        --severity HIGH,CRITICAL \
        --exit-code 0 \
        $image_name

   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "$project_root/.trivyignore":/.trivyignore \
      -v "$trivy_cache_dir:/root/.cache/" \
      aquasec/trivy --no-progress \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        --ignorefile /.trivyignore \
        --exit-code 1 \
        $image_name

   sudo chown -R $USER:$(id -gn) "$trivy_cache_dir" || true
fi


#################################################
# determine effective Jenkins version and apply tags
#################################################
jenkins_version=$(docker run --rm $image_name --version | tail -1)
docker image tag $image_name $image_repo:${jenkins_version%%.*}.x-$base_image_tag #2.x-lts-slim


#################################################
# push image with tags to remote docker image registry
#################################################
if [[ "${DOCKER_PUSH:-0}" == "1" ]]; then
   docker image tag $image_name $docker_registry/$image_name
   docker image tag $image_name $docker_registry/$image_repo:${jenkins_version%%.*}.x-$base_image_tag #2.x-lts-slim

   docker push $docker_registry/$image_name
   docker push $docker_registry/$image_repo:${jenkins_version%%.*}.x-$base_image_tag
fi


#################################################
# remove untagged images
#################################################
# http://www.projectatomic.io/blog/2015/07/what-are-docker-none-none-images/
untagged_images=$(docker images -f "dangling=true" -q --no-trunc)
[[ -n $untagged_images ]] && docker rmi $untagged_images || true


#################################################
# display some image information
#################################################
echo ""
echo "IMAGE NAME"
echo "$image_name"
echo ""
docker images "$image_repo"
echo ""
docker history "$image_name"
