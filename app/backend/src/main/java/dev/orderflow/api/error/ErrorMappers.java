package dev.orderflow.api.error;

import com.fasterxml.jackson.core.JsonProcessingException;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;
import org.jboss.resteasy.reactive.server.ServerExceptionMapper;

import java.util.stream.Collectors;

/** Turns every failure into an {@link ErrorResponse} with a matching HTTP status. */
public class ErrorMappers {

    private static final Logger LOG = Logger.getLogger(ErrorMappers.class);

    @ServerExceptionMapper
    public Response domain(DomainException e) {
        return error(statusOf(e.code()), e.code().name(), e.getMessage());
    }

    @ServerExceptionMapper
    public Response constraintViolation(ConstraintViolationException e) {
        String message = e.getConstraintViolations().stream()
                .map(ErrorMappers::describe)
                .sorted()
                .collect(Collectors.joining("; "));
        return error(400, ErrorCode.VALIDATION_ERROR.name(), message);
    }

    @ServerExceptionMapper
    public Response malformedJson(JsonProcessingException e) {
        return error(400, "MALFORMED_REQUEST", "Request body is not valid JSON for this endpoint.");
    }

    @ServerExceptionMapper
    public Response webApplication(WebApplicationException e) {
        int status = e.getResponse().getStatus();
        if (status == 400) {
            return error(400, "MALFORMED_REQUEST", "Request body is not valid JSON for this endpoint.");
        }
        String code = switch (status) {
            case 404 -> "NOT_FOUND";
            case 405 -> "METHOD_NOT_ALLOWED";
            case 406 -> "NOT_ACCEPTABLE";
            case 415 -> "UNSUPPORTED_MEDIA_TYPE";
            default -> status >= 500 ? "INTERNAL_ERROR" : "HTTP_" + status;
        };
        return error(status, code, e.getMessage());
    }

    @ServerExceptionMapper
    public Response unexpected(Exception e) {
        LOG.error("Unexpected error", e);
        return error(500, "INTERNAL_ERROR", "Unexpected error. Check the backend logs.");
    }

    static int statusOf(ErrorCode code) {
        return switch (code) {
            case VALIDATION_ERROR -> 400;
            case PRODUCT_NOT_FOUND, ORDER_NOT_FOUND, INVOICE_NOT_AVAILABLE, IMAGE_NOT_AVAILABLE -> 404;
            case OUT_OF_STOCK, INVALID_ORDER_TRANSITION -> 409;
        };
    }

    private static String describe(ConstraintViolation<?> violation) {
        String path = violation.getPropertyPath().toString();
        // Drop the "method.argN." prefix of method-parameter violations.
        String field = path.substring(path.lastIndexOf('.') + 1);
        return field + " " + violation.getMessage();
    }

    private static Response error(int status, String code, String message) {
        return Response.status(status)
                .type(MediaType.APPLICATION_JSON_TYPE)
                .entity(new ErrorResponse(code, message))
                .build();
    }
}
