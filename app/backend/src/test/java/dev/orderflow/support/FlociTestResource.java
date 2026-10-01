package dev.orderflow.support;

import io.floci.testcontainers.FlociContainer;
import io.quarkus.test.common.QuarkusTestResourceLifecycleManager;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Starts Floci with Testcontainers for {@code @QuarkusTest} classes:
 *
 * <pre>{@code
 * @QuarkusTest
 * @WithTestResource(FlociTestResource.class)
 * class DynamoOrderRepositoryTest { ... }
 * }</pre>
 *
 * <p>Each start creates tables, queue and bucket with a unique suffix, so test
 * classes never see each other's data. Admin endpoints are enabled. Pass
 * {@code initArgs = @ResourceArg(name = "processor.enabled", value = "false")}
 * to stop the background order processor (useful when a test must observe a
 * PENDING order or read the queue itself).
 *
 * <p>The Floci image comes from the {@code floci.image} system property, set
 * by the pom, so the version is pinned in one place.
 */
public class FlociTestResource implements QuarkusTestResourceLifecycleManager {

    public static final String PROCESSOR_ENABLED_ARG = "processor.enabled";

    private static final String DEFAULT_IMAGE = "floci/floci:2.1.0";

    private FlociContainer floci;
    private boolean processorEnabled = true;

    @Override
    public void init(Map<String, String> initArgs) {
        processorEnabled = Boolean.parseBoolean(initArgs.getOrDefault(PROCESSOR_ENABLED_ARG, "true"));
    }

    @Override
    public Map<String, String> start() {
        floci = new FlociContainer(System.getProperty("floci.image", DEFAULT_IMAGE));
        floci.start();

        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Map<String, String> config = new HashMap<>(FlociResources.create(
                floci.getEndpoint(), floci.getRegion(), floci.getAccessKey(), floci.getSecretKey(), suffix));
        config.put("orderflow.admin.enabled", "true");
        config.put("orderflow.processor.enabled", Boolean.toString(processorEnabled));
        return config;
    }

    @Override
    public void stop() {
        if (floci != null) {
            floci.stop();
        }
    }
}
