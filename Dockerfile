# syntax=docker/dockerfile:1

ARG JAVA_VERSION=21
ARG MAVEN_VERSION=3.9.11

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

FROM eclipse-temurin:${JAVA_VERSION}-jre AS runtime
ARG JAVA_VERSION
WORKDIR /opt/config-server

# Create an unprivileged user
RUN groupadd --system config \
 && useradd --system --gid config --shell /usr/sbin/nologin config
USER config

ENV JAVA_OPTS=""
ENV SPRING_PROFILES_ACTIVE=git
ENV CONFIG_GIT_URI=https://github.com/spring-cloud-samples/config-repo
ENV CONFIG_GIT_DEFAULT_LABEL=main

COPY --from=build /workspace/app/target/config-server.jar app.jar

EXPOSE 8888
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /opt/config-server/app.jar"]
