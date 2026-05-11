# Global args
ARG TARGETARCH
ARG JAVA_VERSION=17
ARG NODE_VERSION=24
ARG UBUNTU_VERSION=24.04

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

ARG PRINCE_VERSION=16.2
ARG PRINCE_AMD64_SHA256=305d755ff6437e855c151920d1363970d8cc7bff1ea4006290c36ad5d8e06c69
ARG PRINCE_ARM64_SHA256=c8f411c0a06fef8522ae17cdcabfb1992379f017dcd213812154ca6e3cb762bc

ARG SAXON_EDITION_VERSION=SaxonHE12-9
ARG SAXON_SHA256=f2895bef3794112c650a158be27c39a86e88c1717ebb8e0e88067d1f07635d12

ARG SCHEMATRON_VERSION=9.1.1
ARG SCHEMATRON_SHA256=41ef6634ac67dea1a072026720d3be62066508441c5260fe20aae97025592027

ARG XERCES_VERSION=28.1.0.1
ARG XERCES_SHA256=65cf8c7c41cce1410bfec7739ac4c65ffebb91bb70b1d24669f95833e125cad8

# Alias for Eclipse Temurin Java image
FROM eclipse-temurin:${JAVA_VERSION} AS temurin


#################
# Stage 1: BASE #
#################
FROM ubuntu:24.04 AS base

ENV TZ=Europe/Berlin

USER root

RUN echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker && \
    echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates fonts-stix libaom3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


################
# Stage 2: PRINCE #
###################
FROM base AS prince-build

ARG TARGETARCH
ARG UBUNTU_VERSION
ARG PRINCE_VERSION
ARG PRINCE_AMD64_SHA256
ARG PRINCE_ARM64_SHA256

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # download and install prince .deb
    TARGETARCH="${TARGETARCH:-amd64}" && \
    PRINCE_DEB_FILE="prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_${TARGETARCH}.deb" && \
    curl --proto '=https' --tlsv1.2 -fL -o ${PRINCE_DEB_FILE} https://www.princexml.com/download/${PRINCE_DEB_FILE} && \
    case "${TARGETARCH}" in \
        amd64) PRINCE_SHA256="${PRINCE_AMD64_SHA256}" ;; \
        arm64) PRINCE_SHA256="${PRINCE_ARM64_SHA256}" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    echo "${PRINCE_SHA256}  ./${PRINCE_DEB_FILE}" | sha256sum -c - && \
    dpkg -i ./${PRINCE_DEB_FILE} || (apt-get update && apt-get install -y --no-install-recommends -f) && \
    rm -f ./${PRINCE_DEB_FILE} && \
    # link ca-certificates
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/prince/etc/curl-ca-bundle.crt && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


#################
# Stage 3: NODE #
#################
FROM base AS node-build

ARG NODE_VERSION

ENV NODE_ENV=production

COPY ["package.json", "package-lock.json*", "/opt/docker-mei/"]

RUN DEBIAN_FRONTEND=noninteractive \
    # install nodejs from signed NodeSource apt repository
    apt-get update && \
    apt-get install -y --no-install-recommends curl gpg && \
    install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    chmod 0644 /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    # setup node app for rendering MEI files to SVG using Verovio Toolkit
    cd /opt/docker-mei && \
    npm ci --omit=dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY ["index.js", "/opt/docker-mei/"]


################
# Stage 4: ANT #
################
FROM base AS ant-build

ARG ANT_VERSION
ARG ANT_SHA256
ARG SAXON_EDITION_VERSION
ARG SAXON_SHA256
ARG XERCES_VERSION
ARG XERCES_SHA256
ARG SCHEMATRON_VERSION
ARG SCHEMATRON_SHA256

ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV PATH=${PATH}:${ANT_HOME}/bin

ADD --checksum=sha256:${ANT_SHA256} https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz /tmp/
ADD --checksum=sha256:${SAXON_SHA256} https://github.com/Saxonica/Saxon-HE/releases/download/${SAXON_EDITION_VERSION}/${SAXON_EDITION_VERSION}J.zip /tmp/
ADD --checksum=sha256:${XERCES_SHA256} https://www.oxygenxml.com/maven/com/oxygenxml/oxygen-patched-xerces/${XERCES_VERSION}/oxygen-patched-xerces-${XERCES_VERSION}.jar /tmp/
ADD --checksum=sha256:${SCHEMATRON_SHA256} https://repo1.maven.org/maven2/com/helger/schematron/ph-schematron-ant-task/${SCHEMATRON_VERSION}/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar /tmp/

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y --no-install-recommends unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # setup ant
    tar -xf /tmp/apache-ant-${ANT_VERSION}-bin.tar.gz -C /opt && \
    # setup saxon
    unzip -j /tmp/${SAXON_EDITION_VERSION}J.zip "*.jar" -d ${ANT_HOME}/lib && \
    # setup xerces
    cp /tmp/oxygen-patched-xerces-${XERCES_VERSION}.jar ${ANT_HOME}/lib && \
    # setup schematron
    cp /tmp/ph-schematron-ant-task-${SCHEMATRON_VERSION}-jar-with-dependencies.jar ${ANT_HOME}/lib && \
    rm -rf /tmp/*


####################
# Stage 5: Runtime #
####################
FROM base AS runtime

ARG ANT_VERSION

LABEL org.opencontainers.image.authors="https://github.com/riedde, https://github.com/bwbohl, https://github.com/kepper, https://github.com/musicEnfanthen" \
      org.opencontainers.image.source="https://github.com/music-encoding/docker-mei" \
      org.opencontainers.image.revision="v0.0.2"

ENV TZ=Europe/Berlin
ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV JAVA_HOME=/opt/java/openjdk

# Install runtime dependencies for Prince and Git directly.
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        libavif16 \
        libcurl4t64 \
        libfontconfig1 \
        libfreetype6 \
        libgif7 \
        libjpeg8 \
        liblcms2-2 \
        libpng16-16t64 \
        libtiff6 \
        libwebp7 \
        libwebpdemux2 \
        libxml2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Java & Ant (including Saxon, Schematron and Xerces)
COPY --from=temurin $JAVA_HOME $JAVA_HOME
COPY --from=ant-build $ANT_HOME $ANT_HOME
# Prince
COPY --from=prince-build /usr/bin/prince /usr/bin/prince
COPY --from=prince-build /usr/lib/prince /usr/lib/prince
# Node
COPY --from=node-build /usr/bin/node /usr/bin/node

# Main directory
COPY --from=node-build /opt/docker-mei /opt/docker-mei

RUN ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/prince/etc/curl-ca-bundle.crt

# Set path
ENV PATH=${PATH}:${ANT_HOME}/bin:${JAVA_HOME}/bin:/usr/local/bin

WORKDIR /opt/docker-mei
