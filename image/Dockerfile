#syntax=docker/dockerfile:1.2
# Copyright 2020-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-jenkins-ext
#

# https://hub.docker.com/r/jenkins/jenkins/tags?page=1&name=lts-slim
# https://github.com/jenkinsci/docker/blob/master/11/debian/buster-slim/hotspot/Dockerfile
ARG BASE_IMAGE=jenkins:jenkins/lts-slim

FROM ${BASE_IMAGE}

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

USER root

SHELL ["/bin/bash", "-c"]

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

ARG BASE_LAYER_CACHE_KEY
ARG INSTALL_SUPPORT_TOOLS=0

RUN --mount=type=bind,source=.shared,target=/mnt/shared \
  set -eu && \
  /mnt/shared/cmd/debian-install-os-updates.sh && \
  /mnt/shared/cmd/debian-install-support-tools.sh && \
  /mnt/shared/cmd/debian-cleanup.sh

# https://github.com/jenkinsci/plugin-installation-manager-tool/releases
ARG JENKINS_PLUGIN_MANAGER_MIN_VERSION='2.5.0'

ARG BUILD_DATE
ARG GIT_BRANCH
ARG GIT_COMMIT_HASH
ARG GIT_COMMIT_DATE
ARG GIT_REPO_URL

LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$GIT_COMMIT_HASH \
  org.label-schema.vcs-url=$GIT_REPO_URL

# Default configuration: can be overridden at the docker command line
ENV \
  INIT_SH_FILE='' \
  #
  CASC_JENKINS_CONFIG=$REF/config/ \
  REQUIRED_PLUGINS='' \
  REQUIRED_PLUGINS_FILE=''

COPY image/jenkins-ext.sh /usr/local/bin/jenkins-ext.sh
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins-ext.sh"]

RUN \
  set -eu && \
  echo -e "\
GIT_REPO:    $GIT_REPO_URL\n\
GIT_BRANCH:  $GIT_BRANCH\n\
GIT_COMMIT:  $GIT_COMMIT_HASH @ $GIT_COMMIT_DATE\n\
IMAGE_BUILD: $BUILD_DATE\n" >/opt/build_info && \
  cat /opt/build_info && \
  #
  plugin_manager_jar=/usr/lib/jenkins-plugin-manager.jar && \
  # check if a plugin manager version is installed already
  if [[ -e /usr/lib/jenkins-plugin-manager.jar ]]; then \
     installed_version=$(java -jar $plugin_manager_jar --version) && \
     # check if required version is installed already
     if [[ $JENKINS_PLUGIN_MANAGER_MIN_VERSION != $installed_version ]]; then \
        # check if installed version in the base image is older than required version
        # https://stackoverflow.com/a/25731924
        if [[ $JENKINS_PLUGIN_MANAGER_MIN_VERSION == $(echo -e "$JENKINS_PLUGIN_MANAGER_MIN_VERSION\n$installed_version" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -g | tail -1) ]]; then \
           echo "Uninstalling [Jenkins plugin manager ${installed_version}]..." && \
           rm -f $plugin_manager_jar; \
        fi \
      fi \
  fi && \
  if [[ ! -e $plugin_manager_jar ]]; then \
     echo "Installing [Jenkins plugin manager ${JENKINS_PLUGIN_MANAGER_MIN_VERSION}]..." && \
     curl -Lf https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$JENKINS_PLUGIN_MANAGER_MIN_VERSION/jenkins-plugin-manager-${JENKINS_PLUGIN_MANAGER_MIN_VERSION}.jar -o $plugin_manager_jar; \
  fi && \
  echo "Installed Jenkins plugin manager version: $(java -jar $plugin_manager_jar --version)" && \
  #
  chmod 775 /usr/local/bin/jenkins-ext.sh

COPY .shared/lib/bash-init.sh /opt/bash-init.sh

USER jenkins

RUN \
  set -eu && \
  echo "Installing [configuration-as-code] Jenkins plugin..." && \
  export CACHE_DIR=/tmp/.pluginscache && \
  java -jar /usr/lib/jenkins-plugin-manager.jar --plugins configuration-as-code:latest && \
  rm -rf /tmp/.pluginscache && \
  mkdir $REF/config
