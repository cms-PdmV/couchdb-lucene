# Build all the packages
# ===================================
FROM debian:bookworm-slim@sha256:6bdbd579ba71f6855deecf57e64524921aed6b97ff1e5195436f244d2cb42b12 as builder
RUN apt update -y && apt upgrade -y && apt install -y wget && apt install -y git

WORKDIR /tmp

ENV PACKAGE_PATH='/opt/java'
ENV JAVA_TAR_NAME='java.tar.gz'
ENV MAVEN_TAR_NAME='maven.tar.gz'
ENV JAVA_URL='https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-x64_bin.tar.gz'
ENV MAVEN_URL='https://downloads.apache.org/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz'
ENV JAVA_ENV_FILE='/etc/profile.d/java.sh'

# Install Java and Maven
RUN mkdir -p $PACKAGE_PATH
RUN wget -O ./${JAVA_TAR_NAME} ${JAVA_URL} && wget -O ./${MAVEN_TAR_NAME} ${MAVEN_URL}
RUN tar -xvf ./${JAVA_TAR_NAME} -C ${PACKAGE_PATH} && \
    tar -xvf ./${MAVEN_TAR_NAME} -C ${PACKAGE_PATH}

RUN mv $(find ${PACKAGE_PATH} -maxdepth 1 -type d -name 'jdk*') ${PACKAGE_PATH}/jdk && \
    mv $(find ${PACKAGE_PATH} -maxdepth 1 -type d -name 'apache-maven*') ${PACKAGE_PATH}/maven

ENV JAVA_HOME=${PACKAGE_PATH}/jdk
ENV M2_HOME=${PACKAGE_PATH}/maven
ENV MAVEN_HOME=${M2_HOME}
ENV PATH=${PATH}:${JAVA_HOME}/bin:${M2_HOME}/bin

# Download and build CouchDB Lucene
ENV COUCHDB_LUCENE_SRC_NAME='couchdb-lucene-src'
ENV COUCHDB_LUCENE_SRC='https://github.com/cms-PdmV/couchdb-lucene.git'
RUN git clone --depth 1 ${COUCHDB_LUCENE_SRC} ${COUCHDB_LUCENE_SRC_NAME} && \
    mvn -f ./${COUCHDB_LUCENE_SRC_NAME} 
RUN tar -xvf $(find ./${COUCHDB_LUCENE_SRC_NAME}/target/ -maxdepth 1 -type f -name 'couchdb-lucene-*.tar.gz') && \
    mv $(find . -maxdepth 1 -type d -name 'couchdb-lucene-*-SNAPSHOT') /opt/couchdb-lucene

# Run the service
# ===================================
FROM debian:bookworm-slim@sha256:6bdbd579ba71f6855deecf57e64524921aed6b97ff1e5195436f244d2cb42b12 as service
RUN apt update -y && apt upgrade -y

# Runtime user
RUN addgroup --gid 1001 pdmv && \
    useradd --uid 1001 --gid 1001 --shell /bin/bash pdmv && \
    usermod -aG 0 pdmv

COPY --chown=0:0 --from=builder /opt /opt

# Create a default directory for the indexes
RUN mkdir -p /opt/couchdb-lucene/indexes && \
    chmod 770 /opt/couchdb-lucene/indexes

# Update the path
ENV JAVA_HOME=/opt/java/jdk
ENV M2_HOME=/opt/java/maven
ENV LUCENE_HOME=/opt/couchdb-lucene
ENV MAVEN_HOME=${M2_HOME}
ENV PATH=${PATH}:${JAVA_HOME}/bin:${M2_HOME}/bin:${LUCENE_HOME}/bin

USER 1001

CMD [ "run" ] 
