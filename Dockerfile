# Global args
ARG JAVA_VERSION=17

# Alias for Eclipse Temurin Java image
FROM eclipse-temurin:${JAVA_VERSION} AS temurin


#################
# Stage 1: BASE #
#################
FROM ubuntu:24.10 AS base

ARG ANT_VERSION=1.10.14
ARG NODE_VERSION=22
ARG PRINCE_VERSION=15.4.1
ARG SAXON_EDITION_VERSION=SaxonHE12-5
ARG SCHEMATRON_VERSION=8.0.0
ARG UBUNTU_VERSION=24.04
ARG XERCES_VERSION=26.1.0.1

ARG TARGETARCH
ARG PRINCE_DEB_FILE=prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_${TARGETARCH}.deb

ENV TZ=Europe/Berlin

USER root

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker
RUN DEBIAN_FRONTEND=noninteractive \
    # update and install common dependencies
    apt-get update && apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends apt-utils ca-certificates curl unzip && \
    # install prince
    curl --proto '=https' --tlsv1.2 -LO https://www.princexml.com/download/${PRINCE_DEB_FILE} && \
    apt-get install -y --no-install-recommends libc6 libaom-dev fonts-stix ./${PRINCE_DEB_FILE} && \
    # link ca-certificates
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/prince/etc/curl-ca-bundle.crt


################
# Stage 2: GIT #
################
FROM base AS git-build

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends git


#################
# Stage 3: NODE #
#################
FROM base AS node-build

ENV NODE_ENV=production

COPY ["index.js", "package.json", "package-lock.json*", "/opt/docker-mei/"]

RUN DEBIAN_FRONTEND=noninteractive \
    # install nodejs
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y --no-install-recommends nodejs && \
    # setup node app for rendering MEI files to SVG using Verovio Toolkit
    cd /opt/docker-mei && \
    npm install --omit=dev


################
# Stage 4: ANT #
################
FROM base AS ant-build

ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV PATH=${PATH}:${ANT_HOME}/bin

ADD https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    https://github.com/Saxonica/Saxon-HE/releases/download/${SAXON_EDITION_VERSION}/${SAXON_EDITION_VERSION}J.zip \
    https://www.oxygenxml.com/maven/com/oxygenxml/oxygen-patched-xerces/${XERCES_VERSION}/oxygen-patched-xerces-${XERCES_VERSION}.jar \
    https://repo1.maven.org/maven2/com/helger/schematron/ph-schematron-ant-task/${SCHEMATRON_VERSION}/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar \
    /tmp/

RUN DEBIAN_FRONTEND=noninteractive \
    # setup ant
    tar -xvf /tmp/apache-ant-${ANT_VERSION}-bin.tar.gz -C /opt && \
    # setup saxon
    unzip /tmp/${SAXON_EDITION_VERSION}J.zip -d ${ANT_HOME}/lib && \
    # setup xerces
    cp /tmp/oxygen-patched-xerces-${XERCES_VERSION}.jar ${ANT_HOME}/lib && \
    # setup schematron
    cp /tmp/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar ${ANT_HOME}/lib


####################
# Stage 6: Runtime #
####################
FROM base AS runtime

LABEL org.opencontainers.image.authors="https://github.com/riedde" \
      org.opencontainers.image.authors="https://github.com/bwbohl" \
      org.opencontainers.image.authors="https://github.com/kepper" \
      org.opencontainers.image.authors="https://github.com/musicEnfanthen" \
      org.opencontainers.image.source="https://github.com/music-encoding/docker-mei" \
      org.opencontainers.image.revision="v0.0.1"

ENV TZ=Europe/Berlin
ENV ANT_HOME=/opt/apache-ant-1.10.14
ENV JAVA_HOME=/opt/java/openjdk

# Java & Ant (including Saxon, Schematron and Xerces)
COPY --from=temurin $JAVA_HOME $JAVA_HOME
COPY --from=ant-build $ANT_HOME $ANT_HOME
# Git
COPY --from=git-build /usr/bin/git /usr/bin/git
COPY --from=git-build /usr/lib/git-core /usr/lib/git-core
COPY --from=git-build /usr/share/git-core /usr/share/git-core
# Node
COPY --from=node-build /usr/bin/node /usr/bin/node
COPY --from=node-build /usr/lib/node_modules /usr/lib/node_modules

# Main directory
COPY --from=node-build /opt/docker-mei /opt/docker-mei

# Set path
ENV PATH=${PATH}:${ANT_HOME}/bin:${JAVA_HOME}/bin:/usr/local/bin

WORKDIR /opt/docker-mei
