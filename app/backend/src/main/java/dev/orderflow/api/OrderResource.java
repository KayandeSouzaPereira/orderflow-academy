package dev.orderflow.api;

import dev.orderflow.api.dto.CreateOrderRequest;
import dev.orderflow.api.dto.HistoryEntryResponse;
import dev.orderflow.api.dto.OrderResponse;
import dev.orderflow.api.dto.PresignedUrlResponse;
import dev.orderflow.api.error.ErrorResponse;
import dev.orderflow.application.CancelOrderUseCase;
import dev.orderflow.application.CreateOrderUseCase;
import dev.orderflow.application.OrderQueries;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import dev.orderflow.domain.Order;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;

@Path("/api/orders")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Orders")
public class OrderResource {

    private final CreateOrderUseCase createOrder;
    private final CancelOrderUseCase cancelOrder;
    private final OrderQueries queries;

    public OrderResource(CreateOrderUseCase createOrder, CancelOrderUseCase cancelOrder, OrderQueries queries) {
        this.createOrder = createOrder;
        this.cancelOrder = cancelOrder;
        this.queries = queries;
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @APIResponse(responseCode = "201", description = "Order created as PENDING",
            content = @Content(schema = @Schema(implementation = OrderResponse.class)))
    @APIResponse(responseCode = "400", description = "Invalid e-mail, no items or quantity outside 1..10",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown product",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(responseCode = "409", description = "Not enough stock",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public Response create(CreateOrderRequest request, @Context UriInfo uriInfo) {
        if (request == null) {
            throw new DomainException(ErrorCode.VALIDATION_ERROR, "Request body is required.");
        }
        Order order = createOrder.execute(request.toCommand());
        return Response.created(uriInfo.getAbsolutePathBuilder().path(order.id()).build())
                .entity(OrderResponse.from(order))
                .build();
    }

    @GET
    @Path("/{id}")
    @APIResponse(responseCode = "200", description = "The order",
            content = @Content(schema = @Schema(implementation = OrderResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown order",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public OrderResponse get(@PathParam("id") String id) {
        return OrderResponse.from(queries.get(id));
    }

    @GET
    @APIResponse(responseCode = "200", description = "Orders of the customer, newest first")
    @APIResponse(responseCode = "400", description = "customerEmail is missing",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public List<OrderResponse> listByCustomer(@QueryParam("customerEmail") String customerEmail) {
        if (customerEmail == null || customerEmail.isBlank()) {
            throw new DomainException(ErrorCode.VALIDATION_ERROR, "Query parameter customerEmail is required.");
        }
        return queries.listByCustomer(customerEmail).stream().map(OrderResponse::from).toList();
    }

    @POST
    @Path("/{id}/cancel")
    @APIResponse(responseCode = "200", description = "Order cancelled, stock given back",
            content = @Content(schema = @Schema(implementation = OrderResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown order",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    @APIResponse(responseCode = "409", description = "Order is not PENDING",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public OrderResponse cancel(@PathParam("id") String id) {
        return OrderResponse.from(cancelOrder.execute(id));
    }

    @GET
    @Path("/{id}/invoice")
    @APIResponse(responseCode = "200", description = "Pre-signed URL of the invoice PDF",
            content = @Content(schema = @Schema(implementation = PresignedUrlResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown order, or invoice not generated yet",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public PresignedUrlResponse invoice(@PathParam("id") String id) {
        return PresignedUrlResponse.from(queries.invoiceUrl(id));
    }

    @GET
    @Path("/{id}/history")
    @APIResponse(responseCode = "200", description = "Status history of the order, oldest first")
    @APIResponse(responseCode = "404", description = "Unknown order",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public List<HistoryEntryResponse> history(@PathParam("id") String id) {
        return queries.history(id).stream().map(HistoryEntryResponse::from).toList();
    }
}
