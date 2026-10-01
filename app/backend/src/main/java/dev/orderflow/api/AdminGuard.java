package dev.orderflow.api;

import dev.orderflow.api.error.ErrorResponse;
import dev.orderflow.infrastructure.config.OrderflowConfig;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.resteasy.reactive.server.ServerRequestFilter;

import java.util.Optional;

/**
 * Makes {@code /api/admin/*} answer 404, before any body validation, unless
 * {@code orderflow.admin.enabled=true}.
 */
public class AdminGuard {

    private final OrderflowConfig config;

    public AdminGuard(OrderflowConfig config) {
        this.config = config;
    }

    @ServerRequestFilter(preMatching = true)
    public Optional<Response> hideAdminWhenDisabled(ContainerRequestContext request) {
        String path = request.getUriInfo().getPath();
        if (!config.admin().enabled() && (path.equals("/api/admin") || path.startsWith("/api/admin/"))) {
            return Optional.of(Response.status(404)
                    .type(MediaType.APPLICATION_JSON_TYPE)
                    .entity(new ErrorResponse("NOT_FOUND", "Resource not found."))
                    .build());
        }
        return Optional.empty();
    }
}
