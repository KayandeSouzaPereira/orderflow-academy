package dev.orderflow.api;

import dev.orderflow.api.dto.CreateProductRequest;
import dev.orderflow.api.dto.ProductResponse;
import dev.orderflow.api.dto.SetStockRequest;
import dev.orderflow.api.error.ErrorResponse;
import dev.orderflow.application.ProductCatalog;
import dev.orderflow.domain.Product;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriBuilder;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

/**
 * Test-data endpoints. {@link AdminGuard} hides them (404) unless
 * {@code orderflow.admin.enabled=true}.
 */
@Path("/api/admin/products")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Admin (test data)")
public class AdminProductResource {

    private final ProductCatalog catalog;

    public AdminProductResource(ProductCatalog catalog) {
        this.catalog = catalog;
    }

    @POST
    @APIResponse(responseCode = "201", description = "Product created",
            content = @Content(schema = @Schema(implementation = ProductResponse.class)))
    @APIResponse(responseCode = "400", description = "Invalid product",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public Response create(@Valid @NotNull CreateProductRequest request) {
        Product product = catalog.create(request.toNewProduct());
        return Response.created(UriBuilder.fromPath("/api/products/{id}").build(product.id()))
                .entity(ProductResponse.from(product))
                .build();
    }

    @PUT
    @Path("/{id}/stock")
    @APIResponse(responseCode = "200", description = "Stock updated",
            content = @Content(schema = @Schema(implementation = ProductResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown product",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public ProductResponse setStock(@PathParam("id") String id, @Valid @NotNull SetStockRequest request) {
        return ProductResponse.from(catalog.setStock(id, request.stock()));
    }
}
