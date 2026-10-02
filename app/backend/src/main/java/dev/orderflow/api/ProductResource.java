package dev.orderflow.api;

import dev.orderflow.api.dto.PresignedUrlResponse;
import dev.orderflow.api.dto.ProductResponse;
import dev.orderflow.api.error.ErrorResponse;
import dev.orderflow.application.ProductCatalog;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;

import java.util.List;

@Path("/api/products")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Products")
public class ProductResource {

    private final ProductCatalog catalog;

    public ProductResource(ProductCatalog catalog) {
        this.catalog = catalog;
    }

    @GET
    public List<ProductResponse> list() {
        return catalog.list().stream().map(ProductResponse::from).toList();
    }

    @GET
    @Path("/{id}")
    @APIResponse(responseCode = "200", description = "The product",
            content = @Content(schema = @Schema(implementation = ProductResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown product",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public ProductResponse get(@PathParam("id") String id) {
        return ProductResponse.from(catalog.get(id));
    }

    @GET
    @Path("/{id}/image")
    @APIResponse(responseCode = "200", description = "Pre-signed URL of the product image",
            content = @Content(schema = @Schema(implementation = PresignedUrlResponse.class)))
    @APIResponse(responseCode = "404", description = "Unknown product, or product without image",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    public PresignedUrlResponse image(@PathParam("id") String id) {
        return PresignedUrlResponse.from(catalog.imageUrl(id));
    }
}
