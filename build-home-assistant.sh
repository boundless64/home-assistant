#!/bin/bash

HA_LATEST=false

log() {
   now=$(date +"%Y%m%d-%H%M%S")
   echo "$now - $*" >> /Users/ferdl/Development/docker/home-assistant/docker-build.log
}

log ">>--------------------->>"

## #####################################################################
## Home Assistant version
## #####################################################################
if [ "$1" != "" ]; then
   # Provided as an argument
   HA_VERSION=$1
   log "Docker image with Home Assistant $HA_VERSION"
else
   _HA_VERSION="$(cat /Users/ferdl/Development/docker/home-assistant/docker-build.version)"
   HA_VERSION="$(curl 'https://pypi.python.org/pypi/homeassistant/json' | jq '.info.version' | tr -d '"')"
   HA_LATEST=true
   log "Docker image with Home Assistant 'latest' (version $HA_VERSION)"
fi

## #####################################################################
## For hourly (not parameterized) builds (crontab)
## Do nothing: we're trying to build & push the same version again
## #####################################################################
if [ "$HA_LATEST" = true ] && [ "$HA_VERSION" = "$_HA_VERSION" ]; then
   log "Docker image with Home Assistant $HA_VERSION has already been built & pushed"
   log ">>--------------------->>"
   exit 0
fi

## #####################################################################
## python-openzwave must be installed from the tgz downloaded from python-openzwave archive!!!
## #####################################################################

## #####################################################################
## Generate the Dockerfile
## #####################################################################
cat << _EOF_ > Dockerfile
FROM fgabriel/rpi-armv7hf-debian-qemu
MAINTAINER Ferdinand Gabriel <f.gabriel@gidea.at>

RUN [ "cross-build-start" ]

# Base layer
# ENV ARCH=arm
# ENV CROSS_COMPILE=/usr/bin/

# Mouting point for the user's configuration
VOLUME /config

# RUN	adduser --disabled-password --gecos "" python_user
# RUN usermod -a -G dialout python_user

RUN mkdir -p /usr/src/app/build
WORKDIR /usr/src/app

## #####################################################################
## Install some packages
## - curl  für Loxone Steuerung
## - nmap  für device tracking
## - all for z-wave
## #####################################################################

RUN sed -i "s/httpredir.debian.org/debian.ethz.ch/" /etc/apt/sources.list && \
    apt-get clean && apt-get update && \
    apt-get install -y --no-install-recommends build-essential git python3-dev python3-pip python3-sphinx python3-setuptools net-tools cython3 libudev-dev libglib2.0-dev libffi-dev libssl-dev libyaml-dev libmysqlclient-dev bluetooth libbluetooth-dev curl nmap sudo && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## #####################################################################
## sudo is necessary otherwise the upgrade of pip fails (owned by os  - Debian specific)
## sudo pip3 install -U pip is necessary - the old version dont support --no-cache-dir
## cython has to be the newest version - CYTHON is not necessary, because tgz version of python-openzwave is already cythonized
##  && sudo pip3 install --no-cache-dir -U cython
## #####################################################################

RUN sudo pip3 install pip --ignore-installed six && sudo pip3 install --no-cache-dir colorlog

COPY python-openzwave /usr/src/app/build/python-openzwave
COPY script/build_python_openzwave script/build_python_openzwave

RUN script/build_python_openzwave && \
  mkdir -p /usr/local/share/python-openzwave && \
  ln -sf /usr/src/app/build/python-openzwave/openzwave/config /usr/local/share/python-openzwave/config

COPY requirements_all.txt requirements_all.txt

ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8

RUN pip3 install -r requirements_all.txt --ignore-installed && \ 
    pip3 install mysqlclient uvloop holidays

RUN rm -rf /tmp/*

# Copy source
COPY . .

# Start Home Assistant
CMD [ "python3", "-m", "homeassistant", "--config", "/config" ]
RUN [ "cross-build-end" ]
_EOF_

## #####################################################################
## Build the Docker image, tag and push to https://hub.docker.com/
## #####################################################################
log "Building fgabriel/rpi-home-assistant:$HA_VERSION"
docker build -t fgabriel/rpi-home-assistant:$HA_VERSION .

log "Pushing fgabriel/rpi-home-assistant:$HA_VERSION"
docker push fgabriel/rpi-home-assistant:$HA_VERSION

if [ "$HA_LATEST" = true ]; then
   log "Tagging fgabriel/rpi-home-assistant:$HA_VERSION with latest"
   docker tag fgabriel/rpi-home-assistant:$HA_VERSION fgabriel/rpi-home-assistant:latest
   log "Pushing fgabriel/rpi-home-assistant:latest"
   docker push fgabriel/rpi-home-assistant:latest
   echo $HA_VERSION > /Users/ferdl/Development/docker/home-assistant/docker-build.version
fi

log ">>--------------------->>"
