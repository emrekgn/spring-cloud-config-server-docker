package dev.emrea.configserver;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = {
        "SERVER_PORT=9090",
        "SPRING_PROFILES_ACTIVE=native,git",
        "CONFIG_GIT_URI=file:///tmp/configs",
        "CONFIG_GIT_DEFAULT_LABEL=develop",
        "CONFIG_GIT_SEARCH_PATHS=shared,overrides",
        "CONFIG_GIT_CLONE_ON_START=false",
        "CONFIG_GIT_SKIP_SSL_VALIDATION=true",
        "CONFIG_GIT_FORCE_PULL=true",
        "CONFIG_GIT_USERNAME=test-user",
        "CONFIG_GIT_PASSWORD=test-pass"
})
class ConfigServerApplicationOverrideTests {

    @Autowired
    private Environment environment;

    @Test
    void environmentVariablesOverrideYamlDefaults() {
        assertThat(environment.getProperty("server.port")).isEqualTo("9090");
        assertThat(environment.getProperty("spring.profiles.active")).isEqualTo("native,git");
        assertThat(environment.getProperty("spring.cloud.config.server.git.uri"))
                .isEqualTo("file:///tmp/configs");
        assertThat(environment.getProperty("spring.cloud.config.server.git.default-label"))
                .isEqualTo("develop");
        assertThat(environment.getProperty("spring.cloud.config.server.git.search-paths"))
                .isEqualTo("shared,overrides");
        assertThat(environment.getProperty("spring.cloud.config.server.git.clone-on-start"))
                .isEqualTo("false");
        assertThat(environment.getProperty("spring.cloud.config.server.git.skip-ssl-validation"))
                .isEqualTo("true");
        assertThat(environment.getProperty("spring.cloud.config.server.git.force-pull"))
                .isEqualTo("true");
        assertThat(environment.getProperty("spring.cloud.config.server.git.username"))
                .isEqualTo("test-user");
        assertThat(environment.getProperty("spring.cloud.config.server.git.password"))
                .isEqualTo("test-pass");
    }
}
