# spring-cloud-config-server-docker

An unofficial, minimal Spring Cloud Config Server packaged as a Docker image. The image is built from a tiny Spring Boot application plus the official Temurin Alpine JRE, so you get sensible defaults (port `8888`, Git backend) with the smallest possible footprint.

## Build

The Dockerfile accepts build arguments so you can tweak both the JRE version and exposed port. `JAVA_VERSION` defaults to `21` (supported values: `17`, `21`, `25`) and `SERVER_PORT` defaults to `8888`.

```bash
# default JRE 21
docker build -t config-server:21 .

# JRE 17
docker build --build-arg JAVA_VERSION=17 -t config-server:17 .

# JRE 25
docker build --build-arg JAVA_VERSION=25 -t config-server:25 .

# expose/run on port 9090
docker build --build-arg SERVER_PORT=9090 -t config-server:21-9090 .
```

Under the hood a multi-stage build runs Maven with the matching Temurin JDK and copies the resulting fat jar into the corresponding Temurin Alpine JRE image, keeping things as slim as possible. During the build we also update the `java.version` property inside the Maven project so that the compiler always targets the numeric Java release (e.g. `21`). Keep `JAVA_VERSION` to one of the supported major LTS releases, and when overriding `SERVER_PORT` make sure the value matches the port mapping you intend to publish.

## Run

```bash
docker run --rm -p 8888:8888 \
  -e CONFIG_GIT_URI=https://github.com/spring-cloud-samples/config-repo \
  config-server

# custom server port (must match build-time SERVER_PORT)
docker run --rm -p 9090:9090 \
  -e SERVER_PORT=9090 \
  config-server:21-9090
```

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
