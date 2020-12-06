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

if [[ ${DEBUG_ENTRYPOINT:-} == "1" ]]; then
   set -x
fi

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -gt 0 ]] && [[ "$1" != "--"* ]]; then
   exec "$@"
fi

cat <<'EOF'
 _    __                          __   __________
| |  / /__  ____ _____ __________/ /  /  _/_  __/
| | / / _ \/ __ `/ __ `/ ___/ __  /   / /  / /
| |/ /  __/ /_/ / /_/ / /  / /_/ /  _/ /  / /
|___/\___/\__, /\__,_/_/   \__,_/  /___/ /_/
         /____/
EOF

cat /opt/build_info
echo
echo JENKINS_HOME: $JENKINS_HOME
echo JENKINS_OPTS: ${JENKINS_OPTS:-}
echo JENKINS_SLAVE_AGENT_PORT: ${JENKINS_SLAVE_AGENT_PORT}
echo JENKINS_REF: $REF
echo

if [[ -f $INIT_SH_FILE ]]; then
   source "$INIT_SH_FILE"
fi

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
        echo "Required plugin [$plugin_name] is not yet installed."
        echo "Installing required Jenkins plugins..."
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
if [[ ${DEBUG_ENTRYPOINT:-} == "1" ]]; then
   exec bash -x /usr/local/bin/jenkins.sh "$@"
else
   exec /usr/local/bin/jenkins.sh "$@"
fi
