# docker-jenkins-ext <a href="https://github.com/vegardit/docker-jenkins-ext/" title="GitHub Repo"><img height="30" src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/github.svg?sanitize=true"></a>

[![Build Status](https://github.com/vegardit/docker-jenkins-ext/workflows/Build/badge.svg "GitHub Actions")](https://github.com/vegardit/docker-jenkins-ext/actions?query=workflow%3ABuild)
[![License](https://img.shields.io/github/license/vegardit/docker-jenkins-ext.svg?label=license)](#license)
[![Docker Pulls](https://img.shields.io/docker/pulls/vegardit/jenkins-ext.svg)](https://hub.docker.com/r/vegardit/jenkins-ext)
[![Docker Stars](https://img.shields.io/docker/stars/vegardit/jenkins-ext.svg)](https://hub.docker.com/r/vegardit/jenkins-ext)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)

1. [What is it?](#what-is-it)
1. [Configuration](#config)
1. [License](#license)


## <a name="what-is-it"></a>What is it?

This docker image extends the official [Jenkins](https://jenkins.io) docker image [`jenkins:lts/jenkins:lts-slim`](https://hub.docker.com/jenkins/jenkins/?tab=tags&name=lts-slim) with support for pre-installing plug-ins during container start and pre-configuring the Jenkins instance during container start via YAML files using the [configuration-as-code](http://plugins.jenkins.io/configuration-as-code/) plugin.

It is automatically built **daily** to include the latest OS security fixes.


## <a name="config"></a>Configuration

### Pre-installing Jenkins plugins

You can find a list of available Jenkins plugins at [plugins.jenkins.io](https://plugins.jenkins.io/ui/search/?query=)

To pre-install plugins either:

1. define the environment variable `REQUIRED_PLUGINS` with the list of plugins to pre-install (separated by whitespace), e.g.

   ```bash
   $ docker run -rm -it \
     -p 8080:8080 \
     -e "REQUIRED_PLUGINS=greenballs:latest github:latest" \
     vegardit/jenkins-ext:lts-slim
   ```
1. define the environment variable `REQUIRED_PLUGINS_FILE` pointing to a file containing the list of plugins to pre-install (separated by new lines).

   ```bash
   $ mkdir jenkins_data

   $ echo "
     greenballs:latest
     github:latest
     " > jenkins_data/required_plugins.txt

   $ docker run -rm -it \
       -p 8080:8080 \
       -e REQUIRED_PLUGINS_FILE=/required_plugins.txt \
       -v myfolder/required_plugins.txt:/required_plugins.txt:ro \
       vegardit/jenkins-ext:lts-slim
   ```

To keep pre-installed plugins between container restarts, mount a volume or local folder to `/usr/share/jenkins/ref/plugins`, for example:

```bash
$ mkdir jenkins_data/plugins

$ chown -R 1000:1000 jenkins_data/plugins

$ docker run -rm -it \
  -p 8080:8080 \
  -e "REQUIRED_PLUGINS=greenballs:latest github:latest" \
  -v jenkins_data/plugins:/usr/share/jenkins/ref/plugins:rw
  vegardit/jenkins-ext:lts-slim
```


### Pre-configuring Jenkins

By default the [configuration-as-code](http://plugins.jenkins.io/configuration-as-code/) plugin is configured to look for YAML configuration files under
`/usr/share/jenkins/ref/config/` during Jenkins start. This path can be configured by changing the environment variable `CASC_JENKINS_CONFIG`.


```yaml
# jenkins_data/base-config.yaml
jenkins:
  noUsageStatistics: true
  projectNamingStrategy:
    pattern:
      forceExistingJobs: false
      namePattern: "[a-zA-Z0-9_-. ]+
```

```bash
$ docker run -rm -it \
    -p 8080:8080 \
    -v "jenkins_data/base-config.yaml:/usr/share/jenkins/ref/config/base-config.yaml:ro" \
    vegardit/jenkins-ext:lts-slim
```


## <a name="license"></a>License

All files in this repository are released under the [Apache License 2.0](LICENSE.txt).

Individual files contain the following tag instead of the full license text:
```
SPDX-License-Identifier: Apache-2.0
```

This enables machine processing of license information based on the SPDX License Identifiers that are available here: https://spdx.org/licenses/.
