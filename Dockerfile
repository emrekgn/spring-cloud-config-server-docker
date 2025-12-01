# syntax=docker/dockerfile:1

ARG JAVA_VERSION=21
ARG MAVEN_VERSION=3.9.11
ARG SERVER_PORT=8888

FROM maven:${MAVEN_VERSION}-eclipse-temurin-${JAVA_VERSION} AS build
ARG JAVA_VERSION
WORKDIR /workspace/app

# Resolve dependencies first to leverage Docker layer caching
COPY pom.xml .
RUN mvn versions:set-property \
        -Dproperty=java.version \
        -DnewVersion=${JAVA_VERSION} \
        -DgenerateBackupPoms=false
RUN mvn dependency:go-offline

# Build the Spring Cloud Config Server fat jar
COPY src ./src
RUN mvn package -DskipTests

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
        --add-modules "${deps},jdk.unsupported" \
        --output /opt/jre

# Prepare the entrypoint script that will run inside the scratch image
RUN mkdir -p /opt/config-server \
 && cat <<'EOF' > /opt/config-server/entrypoint.sh
#!/bin/sh
set -e
exec /opt/jre/bin/java $JAVA_OPTS -jar /opt/config-server/app.jar
EOF
RUN chmod +x /opt/config-server/entrypoint.sh

FROM busybox:1.36.1-musl AS shell

FROM scratch AS runtime
ARG SERVER_PORT

ENV JAVA_HOME=/opt/jre
ENV JAVA_OPTS=""
ENV SERVER_PORT=${SERVER_PORT}
ENV SPRING_PROFILES_ACTIVE=git
ENV CONFIG_GIT_URI=https://github.com/spring-cloud-samples/config-repo
ENV CONFIG_GIT_DEFAULT_LABEL=main

WORKDIR /opt/config-server

COPY --from=shell /bin/sh /bin/sh
COPY --from=shell /bin/busybox /bin/busybox

COPY --from=jre-build /etc/passwd /etc/passwd
COPY --from=jre-build /etc/group /etc/group
COPY --from=jre-build /opt/jre /opt/jre
COPY --from=jre-build /opt/config-server/entrypoint.sh /opt/config-server/entrypoint.sh
COPY --from=build /workspace/app/target/config-server.jar /opt/config-server/app.jar

USER config

EXPOSE ${SERVER_PORT}
ENTRYPOINT ["/opt/config-server/entrypoint.sh"]
