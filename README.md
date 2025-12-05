# spring-cloud-config-server-docker

[![Docker Version](https://img.shields.io/docker/v/emrekgn/spring-cloud-config-server/latest)](https://hub.docker.com/r/emrekgn/spring-cloud-config-server)
[![Image Size](https://img.shields.io/docker/image-size/emrekgn/spring-cloud-config-server/latest)](https://hub.docker.com/r/emrekgn/spring-cloud-config-server)
[![License](https://img.shields.io/github/license/emrekgn/spring-cloud-config-server-docker)](https://github.com/emrekgn/spring-cloud-config-server-docker/blob/main/LICENSE)
[![Build Status](https://github.com/emrekgn/spring-cloud-config-server-docker/actions/workflows/docker-image.yml/badge.svg)](https://github.com/emrekgn/spring-cloud-config-server-docker/actions/workflows/docker-image.yml)

An unofficial, minimal Spring Cloud Config Server packaged as a Docker image. The image is built from a tiny Spring Boot application and a custom `jlink` runtime distilled from Temurin, so you get sensible defaults (port `8888`, Git backend) with the smallest possible footprint.

## Quickstart

```bash
# Run with defaults (Git backend pointing to the sample repo)
docker run --rm -p 8888:8888 emrekgn/spring-cloud-config-server:latest

# Override Git repository and branch/tag
docker run --rm -p 8888:8888 \
  -e CONFIG_GIT_URI=https://github.com/your-org/your-configs \
  -e CONFIG_GIT_DEFAULT_LABEL=prod \
  emrekgn/spring-cloud-config-server:latest

# Change server port and activate extra profiles
docker run --rm -p 9090:9090 \
  -e SERVER_PORT=9090 \
  -e SPRING_PROFILES_ACTIVE=native,git \
  emrekgn/spring-cloud-config-server:latest

# Mount an external application.yml into the container
docker run --rm -p 8888:8888 \
  -v "$(pwd)/config/application.yml:/opt/config-server/config/application.yml:ro" \
  emrekgn/spring-cloud-config-server:latest

# Use native (filesystem) backend instead of Git
docker run --rm -p 8888:8888 \
  -e SPRING_PROFILES_ACTIVE=native \
  -e SPRING_CLOUD_CONFIG_SERVER_NATIVE_SEARCH_LOCATIONS=file:/opt/config-server/native \
  -v "$(pwd)/native-config:/opt/config-server/native:ro" \
  emrekgn/spring-cloud-config-server:latest
```

## Build

The Dockerfile accepts build arguments so you can tweak the Temurin JRE version used to build and package the server. `JAVA_VERSION` defaults to `21` (supported values: `17`, `21`, `25`).

```bash
# default JRE 21
docker build -t config-server:21 .

# JRE 17
docker build --build-arg JAVA_VERSION=17 -t config-server:17 .

# JRE 25
docker build --build-arg JAVA_VERSION=25 -t config-server:25 .
```

Under the hood a multi-stage build runs Maven with the matching Temurin JDK, derives the required Java modules via `jdeps`, and then builds a trimmed runtime with `jlink`. The result plus a tiny BusyBox shell are copied into a `scratch` final image, so the shipped container only holds the custom JRE and the Spring Boot jar. During the build we also update the `java.version` property inside the Maven project so that the compiler always targets the numeric Java release (e.g. `21`). Keep `JAVA_VERSION` to one of the supported major LTS releases, and when overriding `SERVER_PORT` make sure the value matches the port mapping you intend to publish.

## Run

```bash
docker run --rm -p 8888:8888 \
  -e CONFIG_GIT_URI=https://github.com/spring-cloud-samples/config-repo \
  config-server

# custom server port (override at runtime, no rebuild required)
docker run --rm -p 9090:9090 \
  -e SERVER_PORT=9090 \
  config-server

The container defaults to port `8888`, but overriding `SERVER_PORT` at runtime is enough to listen on any other port—no rebuild or custom image tag required (just remember to update your `-p host:container` mapping).
```

## Publishing tips

When pushing to a registry and you only care about transfer size (not runtime footprint), build the image with BuildKit compression disabled plus SBOM/provenance metadata skipped:

```bash
docker buildx build \
  --sbom=false \
  --provenance=false \
  --no-cache \
  --compression=gzip \
  -t your-registry/config-server:21 .
```

Using `--compression=zstd` typically yields similar savings (roughly 5–15 MB per image) depending on registry support.

Override the environment variables below to point at your own configuration Git repository or change runtime behavior.

| Variable | Default | Purpose |
| --- | --- | --- |
| `SPRING_PROFILES_ACTIVE` | `git` | Spring profile(s) to load |
| `SERVER_PORT` | `8888` | HTTP port Config Server listens on |
| `CONFIG_GIT_URI` | `https://github.com/spring-cloud-samples/config-repo` | Source repository for configuration |
| `CONFIG_GIT_DEFAULT_LABEL` | `main` | Git branch/tag |
| `CONFIG_GIT_SEARCH_PATHS` | *(empty)* | Comma-separated list of search paths |
| `CONFIG_GIT_CLONE_ON_START` | `true` | Ensure repo is cloned before serving requests |
| `CONFIG_GIT_SKIP_SSL_VALIDATION` | `false` | Skip SSL validation for Git |
| `CONFIG_GIT_FORCE_PULL` | `false` | Force pull on start |
| `CONFIG_GIT_USERNAME` | *(empty)* | Username for private repositories |
| `CONFIG_GIT_PASSWORD` | *(empty)* | Password/token for private repositories |
| `JAVA_OPTS` | *(empty)* | Extra JVM flags (e.g. `-Xmx256m`) |

Any additional Spring configuration can be supplied via environment variables, command-line arguments (`JAVA_OPTS`), or by mounting a custom `application.yml` into `/opt/config-server/config`.

## Health check

Actuator’s `health` and `info` endpoints are exposed at `/actuator`. For example:

```
curl http://localhost:8888/actuator/health
```
