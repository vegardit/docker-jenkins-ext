#!/usr/bin/env bash
#
# Copyright 2020-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
# https://github.com/vegardit/docker-jenkins-ext
#

source /opt/bash-init.sh

#################################################
# check for adhoc command
#################################################
# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -gt 0 ]] && [[ "$1" != "--"* ]]; then
   exec "$@"
fi


#################################################
# print header
#################################################
cat <<'EOF'
      _            _    _              ____ ___
     | | ___ _ __ | | _(_)_ __  ___   / ___|_ _|
  _  | |/ _ \ '_ \| |/ / | '_ \/ __| | |    | |
 | |_| |  __/ | | |   <| | | | \__ \ | |___ | |
  \___/ \___|_| |_|_|\_\_|_| |_|___/  \____|___|

EOF

cat /opt/build_info
echo
echo JENKINS_HOME: $JENKINS_HOME
echo JENKINS_OPTS: ${JENKINS_OPTS:-}
echo JENKINS_SLAVE_AGENT_PORT: ${JENKINS_SLAVE_AGENT_PORT}
echo JENKINS_REF: $REF
echo


#################################################
# load custom init script if specified
#################################################
if [[ -f $INIT_SH_FILE ]]; then
   log INFO "Loading [$INIT_SH_FILE]..."
   source "$INIT_SH_FILE"
fi


#################################################
# tune some JVM parameters
#################################################
# jenkins.install.runSetupWizard = skip initial setup
export JAVA_OPTS="
 -Djenkins.install.runSetupWizard=false
 -Dfile.encoding=UTF-8
 -Dclient.encoding.override=UTF-8
 -Djava.awt.headless=true
 -Djava.net.preferIPv4Stack=true
 ${JAVA_OPTS:-}
"


#################################################
# installing required plugins
#################################################
if [[ -n ${REQUIRED_PLUGINS:-} || -n ${REQUIRED_PLUGINS_FILE:-} || ! -e $REF/plugins/configuration-as-code.jpi ]]; then
   echo "configuration-as-code:latest" > /tmp/required_plugins.txt
   if [[ -n ${REQUIRED_PLUGINS:-} ]]; then
      for p in $REQUIRED_PLUGINS; do
         echo $p >> /tmp/required_plugins.txt
      done
   fi
   if [[ -n ${REQUIRED_PLUGINS_FILE:-} ]]; then
      cat $REQUIRED_PLUGINS_FILE >> /tmp/required_plugins.txt
   fi

   rm -rf /tmp/required_plugins
   mkdir /tmp/required_plugins

   # check if plugin install is required
   while IFS= read -r line; do
      line=$(echo $line) #trim
      if [[ -z $line ]]; then
         continue;
      fi
      plugin_name=${line%%:*}
      if [[ ! -e $REF/plugins/${plugin_name}.jpi ]]; then
         log INFO "Required plugin [$plugin_name] is not yet installed."
         log INFO "Installing required Jenkins plugins..."
         CACHE_DIR=$REF/plugins/.cache \
         PLUGIN_DIR=/tmp/required_plugins \
         java -jar /usr/lib/jenkins-plugin-manager.jar -f /tmp/required_plugins.txt

         rm -f $REF/plugins/*.jpi
         mv /tmp/required_plugins/*.jpi $REF/plugins
         rm -rf /tmp/required_plugins
         break
      fi
   done < /tmp/required_plugins.txt
fi


#################################################
# loading original entrypoint file
#################################################
# if TRACE_SCRIPTS=1 or  TRACE_SCRIPTS contains a glob pattern that matches $0
if [[ ${TRACE_SCRIPTS:-} == "1" || ${TRACE_SCRIPTS:-} == "$0" ]]; then
   exec bash -x /usr/local/bin/jenkins.sh "$@"
else
   exec /usr/local/bin/jenkins.sh "$@"
fi
