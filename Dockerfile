FROM ubuntu:22.04

LABEL org.opencontainers.image.authors="https://github.com/riedde"
LABEL org.opencontainers.image.authors="https://github.com/bwbohl"
LABEL org.opencontainers.image.authors="https://github.com/kepper"
LABEL org.opencontainers.image.source="https://github.com/music-encoding/docker-mei"
LABEL org.opencontainers.image.revision="v0.0.1"

ARG JAVA_VERSION=17
ARG PRINCE_VERSION=15.3
ARG SAXON_VERSION=SaxonHE12-5
ARG SCHEMATRON_VERSION=8.0.0
ARG UBUNTU_VERSION=22.04
ARG XERCES_VERSION=26.1.0.1

ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
ARG DEB_FILE=prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_${TARGETARCH}.deb

ENV TZ=Europe/Berlin
ENV ANT_VERSION=1.10.14

ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV PATH=${PATH}:${ANT_HOME}/bin
ENV NODE_ENV=production

USER root

ADD https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    https://github.com/Saxonica/Saxon-HE/releases/download/${SAXON_VERSION}/${SAXON_VERSION}J.zip \
    https://www.oxygenxml.com/maven/com/oxygenxml/oxygen-patched-xerces/${XERCES_VERSION}/oxygen-patched-xerces-${XERCES_VERSION}.jar \
    https://repo1.maven.org/maven2/com/helger/schematron/ph-schematron-ant-task/${SCHEMATRON_VERSION}/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar \
    /tmp/

COPY ["index.js", "package.json", "package-lock.json*", "/opt/docker-mei/"]

# Configure the Eclipse Adoptium apt repository
RUN apt-get update && apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends wget apt-transport-https curl ca-certificates && \
    mkdir -p /etc/apt/keyrings && \
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list && \
    # install nodejs
    curl -fsSL https://deb.nodesource.com/setup_18.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    # install prince
    curl --proto '=https' --tlsv1.2 -LO https://www.princexml.com/download/${DEB_FILE} && \
    apt-get install -y --no-install-recommends apt-utils python3-pip temurin-${JAVA_VERSION}-jdk nodejs unzip git libc6 aptitude libaom-dev fonts-stix ./${DEB_FILE} && \
    # link ca-certificates
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/prince/etc/curl-ca-bundle.crt && \
    # setup ant
    tar -xvf /tmp/apache-ant-${ANT_VERSION}-bin.tar.gz -C /opt && \
    # setup saxon
    unzip /tmp/${SAXON_VERSION}J.zip -d ${ANT_HOME}/lib && \
    # setup xerces
    cp /tmp/oxygen-patched-xerces-${XERCES_VERSION}.jar ${ANT_HOME}/lib && \
    # setup schematron
    cp /tmp/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar ${ANT_HOME}/lib && \
    # cleanup
    apt-get purge -y aptitude apt-utils && \
    apt-get autoremove -y && apt-get clean && \
    apt-get clean && \
    rm ${DEB_FILE} nodesource_setup.sh && \
  	cd /opt/docker-mei && \
  	# setup node app for rendering MEI files to SVG using Verovio Toolkit
    npm install --omit=dev	&& \
    # clean temporary folders
    rm -rfv /tmp/* /root/.npm*

WORKDIR /opt/docker-mei
