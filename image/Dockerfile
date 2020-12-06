# Copyright 2020 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-jenkins-ext
#

# https://hub.docker.com/r/jenkins/jenkins/tags?page=1&name=lts-slim
# https://github.com/jenkinsci/docker/blob/master/Dockerfile-slim
ARG BASE_IMAGE=jenkins:jenkins/lts-slim

FROM ${BASE_IMAGE}

LABEL maintainer="Vegard IT GmbH (vegardit.com)"

USER root

SHELL ["/bin/bash", "-c"]

# if set to 1 debug tools are added to the image (htop,less,mc,vim)
ARG DEBUG_BUILD=0

ARG DEBIAN_FRONTEND=noninteractive
ARG LC_ALL=C

ARG BASE_LAYER_CACHE_KEY

RUN \
  set -eu && \
  echo "#################################################" && \
  echo "Installing OS updates..." && \
  echo "#################################################" && \
  apt-get update -y && \
  # https://github.com/phusion/baseimage-docker/issues/319
  apt-get install --no-install-recommends -y apt-utils 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 ) && \
  apt-get upgrade -y && \
  #
  echo "#################################################" && \
  echo "Installing tools..." && \
  echo "#################################################" && \
  apt-get install --no-install-recommends -y curl git less procps && \
  #
  if [ "${DEBUG_BUILD}" = "1" ]; then \
     echo "#################################################" && \
     echo "Installing debugging tools..." && \
     echo "#################################################" && \
     apt-get install --no-install-recommends -y libcomerr2 mc && \
     apt-get install --no-install-recommends -y htop vim && \
     echo -e 'set ignorecase\n\
set showmatch\n\
set novisualbell\n\
set noerrorbells\n\
syntax enable\n\
set mouse-=a' > ~/.vimrc; \
  fi && \
  #
  echo "#################################################" && \
  echo "apt-get clean up..." && \
  echo "#################################################" && \
  apt-get remove apt-utils -y && \
  apt-get clean autoclean && \
  apt-get autoremove --purge -y && \
  #
  echo "#################################################" && \
  echo "Removing logs, caches and temp files..." && \
  echo "#################################################" && \
  rm -rf /var/cache/{apt,debconf} \
     /var/lib/apt/lists/* \
     /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} \
     /tmp/* /var/tmp/*

ARG BUILD_DATE
ARG GIT_BRANCH
ARG GIT_COMMIT_HASH
ARG GIT_COMMIT_DATE
ARG GIT_REPO_URL
ARG JENKINS_PLUGIN_MANAGER_MIN_VERSION='2.1.1'

LABEL \
  org.label-schema.schema-version="1.0" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$GIT_COMMIT_HASH \
  org.label-schema.vcs-url=$GIT_REPO_URL

ENV \
  CASC_JENKINS_CONFIG=$REF/config/ \
  DEBUG_ENTRYPOINT=0 \
  INIT_SH_FILE='' \
  REQUIRED_PLUGINS='' \
  REQUIRED_PLUGINS_FILE=''

COPY jenkins-ext.sh /usr/local/bin/jenkins-ext.sh

RUN \
  echo "GIT_REPO:    $GIT_REPO_URL" > /opt/build_info && \
  echo "GIT_BRANCH:  $GIT_BRANCH" >> /opt/build_info && \
  echo "GIT_COMMIT:  $GIT_COMMIT_HASH @ $GIT_COMMIT_DATE" >> /opt/build_info  && \
  echo "IMAGE_BUILD: $BUILD_DATE" >> /opt/build_info && \
  cat /opt/build_info && \
  ############################################################
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
    curl -L https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$JENKINS_PLUGIN_MANAGER_MIN_VERSION/jenkins-plugin-manager-${JENKINS_PLUGIN_MANAGER_MIN_VERSION}.jar -o $plugin_manager_jar; \
  fi && \
  echo "Installed Jenkins plugin manager version: $(java -jar $plugin_manager_jar --version)" && \
  ############################################################
  chmod 775 /usr/local/bin/jenkins-ext.sh

USER jenkins

RUN \
  echo "Installing [configuration-as-code] Jenkins plugin..." && \
  export CACHE_DIR=/tmp/.pluginscache  && \
  java -jar /usr/lib/jenkins-plugin-manager.jar --plugins configuration-as-code:latest && \
  rm -rf /tmp/.pluginscache && \
  mkdir $REF/config

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins-ext.sh"]
