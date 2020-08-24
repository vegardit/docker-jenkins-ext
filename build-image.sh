#!/usr/bin/env bash
#
# Copyright 2019-2020 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# @author Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-jenkins-ext
#

set -e -u -x

##############################
# execute script with bash if loaded with other shell interpreter
##############################
if [ ! -n "$BASH" ]; then /usr/bin/env bash "$0" "$@"; exit; fi

set -o pipefail

trap 'echo >&2 "$(date +%H:%M:%S) Error - exited with status $? at line $LINENO:"; pr -tn $0 | tail -n+$((LINENO - 3)) | head -n7' ERR


##############################
# specify target docker registry/repo
##############################
docker_registry=${DOCKER_REGISTRY:-docker.io}
docker_repo=${DOCKER_REPO:-vegardit/jenkins-ext}
base_image=${BASE_IMAGE:-jenkins/jenkins:lts-slim}
base_image_tag=${base_image#*:}
image=$docker_repo:$base_image_tag


##############################
# determine directory of current script
##############################
project_root=$(readlink -e $(dirname "${BASH_SOURCE[0]}"))


##############################
# ensure Linux new line chars
##############################
# env -i PATH="$PATH" -> workaround for "find: The environment is too large for exec()"
env -i PATH="$PATH" find "$project_root/image" -type f -exec dos2unix {} \;


##############################
# build the image
##############################
docker build "$project_root/image" \
   --pull \
   --compress \
   `# using the current date as value for BASE_LAYER_CACHE_KEY, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day` \
   --build-arg BASE_LAYER_CACHE_KEY=$(date +%Y%m%d) \
   --build-arg BASE_IMAGE=$base_image \
   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
   --build-arg GIT_BRANCH="${GIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}" \
   --build-arg GIT_COMMIT_DATE="$(date -d @$(git log -1 --format='%at') --utc +'%Y-%m-%d %H:%M:%S UTC')" \
   --build-arg GIT_COMMIT_HASH="$(git rev-parse --short HEAD)" \
   --build-arg GIT_REPO_URL="$(git config --get remote.origin.url)" \
   -t $image \
   "$@"


##############################
# perform security audit using https://github.com/aquasecurity/trivy
##############################
if [[ $OSTYPE != cygwin ]] && [[ $OSTYPE != msys ]]; then
   trivy_cache_dir=${TRIVY_CACHE_DIR:-$HOME/.trivy/cache}
   mkdir -p "$trivy_cache_dir"
   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$trivy_cache_dir:/root/.cache/" \
      aquasec/trivy --no-progress --exit-code 0 --severity HIGH,CRITICAL $image
   docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$trivy_cache_dir:/root/.cache/" \
      aquasec/trivy --no-progress --ignore-unfixed --exit-code 1 --severity HIGH,CRITICAL $image
   sudo chown -R $USER:$(id -gn) "$trivy_cache_dir" || true
fi


##############################
# determine effective Jenkins version and apply tags
##############################
jenkins_version=$(docker run --rm $image --version | tail -1)
docker image tag $image $docker_repo:${jenkins_version%%.*}.x-$base_image_tag #2.x-lts-slim


##############################
# push image with tags to remote docker registry
##############################
if [[ "${DOCKER_PUSH:-0}" == "1" ]]; then
   docker image tag $image $docker_registry/$image
   docker image tag $image $docker_registry/$docker_repo:${jenkins_version%%.*}.x-$base_image_tag #2.x-lts-slim

   docker push $docker_registry/$image
   docker push $docker_registry/$docker_repo:${jenkins_version%%.*}.x-$base_image_tag
fi


#############################
# remove untagged images
#############################
# http://www.projectatomic.io/blog/2015/07/what-are-docker-none-none-images/
docker rmi $(docker images -f "dangling=true" -q) || true


#############################
# display some image information
#############################
echo ""
docker images "$docker_repo"
echo ""
docker history "$image"
