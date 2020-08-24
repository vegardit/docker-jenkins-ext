# Copyright 2019-2020 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# @author Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-jenkins-ext
#

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
  set -x && \
  ############################################################
  echo "Installing OS updates..." && \
  apt-get -y update && \
  apt-get -y upgrade && \
  ############################################################
  if [ "${DEBUG_BUILD}" = "1" ]; then \
     echo "Installing debugging tools..." && \
     apt-get install --no-install-recommends -y libcomerr2 mc && \
     apt-get install --no-install-recommends -y htop less procps vim && \
     echo -e 'set ignorecase\n\
set showmatch\n\
set novisualbell\n\
set noerrorbells\n\
syntax enable\n\
set mouse-=a' > ~/.vimrc; \
  fi && \
  ############################################################
  echo "apt-get clean up..." && \
  apt-get clean autoclean && \
  apt-get autoremove --purge -y && \
  ############################################################
  echo "Removing logs, caches and temp files..." && \
  rm -rf /var/cache/{apt,debconf} \
     /var/lib/apt/lists/* \
     /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} \
     /tmp/* /var/tmp/*

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
  if [[ ! -e /usr/lib/jenkins-plugin-manager.jar ]]; then \
     echo "Installing [Jenkins plugin manager]..." && \
     curl -L https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/plugin-management-parent-pom-2.0.0/jenkins-plugin-manager-2.0.0.jar -o /usr/lib/jenkins-plugin-manager.jar; \
  fi && \
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