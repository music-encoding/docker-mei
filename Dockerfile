# Global args
ARG JAVA_VERSION=17

# Alias for Eclipse Temurin Java image
FROM eclipse-temurin:${JAVA_VERSION} AS temurin


#################
# Stage 1: BASE #
#################
FROM ubuntu:24.04 AS base

ARG TARGETARCH=amd64
ARG UBUNTU_VERSION=24.04
ARG NODE_VERSION=24

# Recompute the SHA-256 values when bumping versions in this stage.
# Prefer publisher-provided checksum/signature files when available; use direct
# `sha256sum` of the artifact only as a fallback when no official checksum exists.
#   curl -fsSL "https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz" | sha256sum
#   curl -fsSL "https://www.princexml.com/download/prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_amd64.deb" | sha256sum
#   curl -fsSL "https://www.princexml.com/download/prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_arm64.deb" | sha256sum
#   curl -fsSL "https://github.com/Saxonica/Saxon-HE/releases/download/${SAXON_EDITION_VERSION}/${SAXON_EDITION_VERSION}J.zip" | sha256sum
#   curl -fsSL "https://repo1.maven.org/maven2/com/helger/schematron/ph-schematron-ant-task/${SCHEMATRON_VERSION}/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar" | sha256sum
#   curl -fsSL "https://www.oxygenxml.com/maven/com/oxygenxml/oxygen-patched-xerces/${XERCES_VERSION}/oxygen-patched-xerces-${XERCES_VERSION}.jar" | sha256sum
ARG ANT_VERSION=1.10.17
ARG ANT_SHA256=9dc984c208585461e81ab34e9bbbfd9b25459956d7b105169ce9f148feded1e9

ARG PRINCE_VERSION=15.4.1
ARG PRINCE_AMD64_SHA256=4ba03194c1639a0956d5261289ef67a2936de2939bbb875877b8c2e64faad8ec
ARG PRINCE_ARM64_SHA256=0a6691ba3f5fd7cc9d1de2d2dd09bed95a64f68f7328b909275bb45aba11ae8d
ARG PRINCE_DEB_FILE=prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_${TARGETARCH}.deb

ARG SAXON_EDITION_VERSION=SaxonHE12-9
ARG SAXON_SHA256=f2895bef3794112c650a158be27c39a86e88c1717ebb8e0e88067d1f07635d12

ARG SCHEMATRON_VERSION=9.1.1
ARG SCHEMATRON_SHA256=41ef6634ac67dea1a072026720d3be62066508441c5260fe20aae97025592027

ARG XERCES_VERSION=28.1.0.1
ARG XERCES_SHA256=65cf8c7c41cce1410bfec7739ac4c65ffebb91bb70b1d24669f95833e125cad8

ENV TZ=Europe/Berlin

USER root

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker
RUN echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker
RUN DEBIAN_FRONTEND=noninteractive \
    # update and install common dependencies
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends apt-utils ca-certificates curl unzip && \
    # install prince runtime deps first
    apt-get install -y --no-install-recommends libc6 libaom-dev fonts-stix && \
    # install prince local .deb using robust dependency repair flow
        curl --proto '=https' --tlsv1.2 -fL -o ${PRINCE_DEB_FILE} https://www.princexml.com/download/${PRINCE_DEB_FILE} && \
        case "${TARGETARCH}" in \
            amd64) PRINCE_SHA256="${PRINCE_AMD64_SHA256}" ;; \
            arm64) PRINCE_SHA256="${PRINCE_ARM64_SHA256}" ;; \
            *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
        esac && \
        echo "${PRINCE_SHA256}  ./${PRINCE_DEB_FILE}" | sha256sum -c - && \
    dpkg -i ./${PRINCE_DEB_FILE} || (apt-get update && apt-get install -y --no-install-recommends -f && dpkg -i ./${PRINCE_DEB_FILE}) && \
    rm -f ./${PRINCE_DEB_FILE} && \
    # link ca-certificates
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/prince/etc/curl-ca-bundle.crt && \
    # cleanup apt metadata to keep base/runtime layers smaller
    apt-get clean && rm -rf /var/lib/apt/lists/*


################
# Stage 2: GIT #
################
FROM base AS git-build

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


#################
# Stage 3: NODE #
#################
FROM base AS node-build

ENV NODE_ENV=production

COPY ["index.js", "package.json", "package-lock.json*", "/opt/docker-mei/"]

RUN DEBIAN_FRONTEND=noninteractive \
    # install nodejs from signed NodeSource apt repository
    apt-get update && \
    apt-get install -y --no-install-recommends gpg && \
    install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    chmod 0644 /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    # setup node app for rendering MEI files to SVG using Verovio Toolkit
    cd /opt/docker-mei && \
    npm install --omit=dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


################
# Stage 4: ANT #
################
FROM base AS ant-build

ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV PATH=${PATH}:${ANT_HOME}/bin

ADD --checksum=sha256:${ANT_SHA256} https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz /tmp/
ADD --checksum=sha256:${SAXON_SHA256} https://github.com/Saxonica/Saxon-HE/releases/download/${SAXON_EDITION_VERSION}/${SAXON_EDITION_VERSION}J.zip /tmp/
ADD --checksum=sha256:${XERCES_SHA256} https://www.oxygenxml.com/maven/com/oxygenxml/oxygen-patched-xerces/${XERCES_VERSION}/oxygen-patched-xerces-${XERCES_VERSION}.jar /tmp/
ADD --checksum=sha256:${SCHEMATRON_SHA256} https://repo1.maven.org/maven2/com/helger/schematron/ph-schematron-ant-task/${SCHEMATRON_VERSION}/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar /tmp/

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

LABEL org.opencontainers.image.authors="https://github.com/riedde, https://github.com/bwbohl, https://github.com/kepper, https://github.com/musicEnfanthen" \
      org.opencontainers.image.source="https://github.com/music-encoding/docker-mei" \
      org.opencontainers.image.revision="v0.0.2"

ENV TZ=Europe/Berlin
ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
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
