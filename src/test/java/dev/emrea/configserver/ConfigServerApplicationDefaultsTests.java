package dev.emrea.configserver;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.cloud.config.server.EnableConfigServer;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = "CONFIG_GIT_CLONE_ON_START=false")
class ConfigServerApplicationDefaultsTests {

    @Autowired
    private Environment environment;

    @Test
    void loadsDocumentedDefaults() {
        assertThat(environment.getProperty("server.port")).isEqualTo("8888");
        assertThat(environment.getProperty("spring.profiles.active")).isEqualTo("git");
        assertThat(environment.getProperty("spring.cloud.config.server.git.uri"))
                .isEqualTo("https://github.com/spring-cloud-samples/config-repo");
        assertThat(environment.getProperty("spring.cloud.config.server.git.default-label"))
                .isEqualTo("main");
        assertThat(environment.getProperty("spring.cloud.config.server.git.search-paths"))
                .isNullOrEmpty();
        assertThat(environment.getProperty("management.endpoints.web.exposure.include"))
                .isEqualTo("health,info");
    }

    @Test
    void configServerAnnotationIsPresent() {
        assertThat(ConfigServerApplication.class.getAnnotation(EnableConfigServer.class)).isNotNull();
    }
}
