# syntax=docker/dockerfile:1

ARG JAVA_VERSION=21
ARG MAVEN_VERSION=3.9.11
ARG SPRING_BOOT_VERSION=4.0.0
ARG SPRING_CLOUD_VERSION=2025.1.0

FROM maven:${MAVEN_VERSION}-eclipse-temurin-${JAVA_VERSION} AS build
ARG JAVA_VERSION
ARG SPRING_BOOT_VERSION
ARG SPRING_CLOUD_VERSION
WORKDIR /workspace/app

# Resolve dependencies first to leverage Docker layer caching
COPY pom.xml .
RUN mvn -B -ntp versions:update-parent \
        -DparentVersion="[${SPRING_BOOT_VERSION}]" \
        -DgenerateBackupPoms=false \
        -DallowSnapshots=false \
        -DforceVersion=true
RUN mvn -B -ntp versions:set-property \
        -Dproperty=spring-cloud.version \
        -DnewVersion=${SPRING_CLOUD_VERSION} \
        -DgenerateBackupPoms=false
RUN mvn -B -ntp versions:set-property \
        -Dproperty=java.version \
        -DnewVersion=${JAVA_VERSION} \
        -DgenerateBackupPoms=false
RUN mvn -B -ntp dependency:go-offline

# Build the Spring Cloud Config Server fat jar
COPY src ./src
RUN mvn -B -ntp package -DskipTests

FROM eclipse-temurin:${JAVA_VERSION} AS jre-build
ARG JAVA_VERSION
WORKDIR /opt/jre-build

# Create the runtime user up front so /etc/passwd can be copied later
RUN groupadd --system config \
 && useradd --system --uid 1001 --gid config --shell /usr/sbin/nologin config

COPY --from=build /workspace/app/target/config-server.jar app.jar

# Derive the minimal module set and build a custom JRE image
RUN set -eux; \
    deps="$(jdeps --ignore-missing-deps --multi-release ${JAVA_VERSION} \
        --print-module-deps app.jar)"; \
    jlink --strip-debug --no-man-pages --no-header-files --compress=2 \
        --add-modules "${deps},jdk.unsupported,java.desktop,java.management,java.logging,java.naming,java.instrument,jdk.crypto.ec" \
        --output /opt/jre; \
    mkdir -p /opt/runtime-libs; \
    for bin in /opt/jre/bin/java /opt/jre/lib/server/libjvm.so; do \
        ldd "$bin" \
        | awk '/=>/ {print $3} /^[[:space:]]*\// {print $1}'; \
    done \
        | sort -u \
        | xargs -r -I{} cp -L --parents {} /opt/runtime-libs

# Prepare the entrypoint script that will run inside the scratch image
RUN mkdir -p /opt/config-server \
 && cat <<'EOF' > /opt/config-server/entrypoint.sh
#!/bin/sh
set -e
exec /opt/jre/bin/java -Djava.security.egd=file:/dev/./urandom -Djava.io.tmpdir=/tmp $JAVA_OPTS -jar /opt/config-server/app.jar
EOF
RUN chmod +x /opt/config-server/entrypoint.sh

FROM busybox:1.36.1-musl AS shell

FROM scratch AS runtime

ENV JAVA_HOME=/opt/jre
ENV JAVA_OPTS=""
ENV HOME=/home/config
ENV SERVER_PORT=8888
ENV SPRING_PROFILES_ACTIVE=git
ENV CONFIG_GIT_URI=https://github.com/spring-cloud-samples/config-repo
ENV CONFIG_GIT_DEFAULT_LABEL=main

WORKDIR /opt/config-server

COPY --from=shell /bin/sh /bin/sh
COPY --from=shell /bin/busybox /bin/busybox
COPY --from=shell /tmp /tmp

RUN /bin/busybox chown 1001:1001 /tmp \
 && /bin/busybox chmod 1777 /tmp

RUN /bin/busybox mkdir -p /home/config/.config/jgit \
 && /bin/busybox chown -R 1001:1001 /home/config

COPY --from=jre-build /etc/passwd /etc/passwd
COPY --from=jre-build /etc/group /etc/group
COPY --from=jre-build /opt/jre /opt/jre
COPY --from=jre-build /opt/runtime-libs/ /
COPY --from=jre-build /opt/config-server/entrypoint.sh /opt/config-server/entrypoint.sh
COPY --from=build /workspace/app/target/config-server.jar /opt/config-server/app.jar

USER config

ENTRYPOINT ["/opt/config-server/entrypoint.sh"]
