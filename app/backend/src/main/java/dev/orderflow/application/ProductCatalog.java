package dev.orderflow.application;

import dev.orderflow.application.port.IdGenerator;
import dev.orderflow.application.port.PresignedUrl;
import dev.orderflow.application.port.ProductImageStorage;
import dev.orderflow.application.port.ProductRepository;
import dev.orderflow.domain.DomainException;
import dev.orderflow.domain.ErrorCode;
import dev.orderflow.domain.Product;

import java.util.Comparator;
import java.util.List;

/** Catalog reads plus the admin operations used to prepare test data. */
public class ProductCatalog {

    public record NewProduct(String name, String description, long priceInCents, int stock, String imageKey) {
    }

    private final ProductRepository products;
    private final ProductImageStorage images;
    private final IdGenerator ids;

    public ProductCatalog(ProductRepository products, ProductImageStorage images, IdGenerator ids) {
        this.products = products;
        this.images = images;
        this.ids = ids;
    }

    /** All products, sorted by name so the catalog order is stable. */
    public List<Product> list() {
        return products.findAll().stream()
                .sorted(Comparator.comparing(Product::name).thenComparing(Product::id))
                .toList();
    }

    public Product get(String productId) {
        return products.findById(productId).orElseThrow(() -> notFound(productId));
    }

    public PresignedUrl imageUrl(String productId) {
        Product product = get(productId);
        if (product.imageKey() == null || product.imageKey().isBlank()) {
            throw new DomainException(ErrorCode.IMAGE_NOT_AVAILABLE,
                    "Product " + productId + " has no image.");
        }
        return images.presign(product.imageKey());
    }

    public Product create(NewProduct request) {
        Product product = new Product(ids.newId(), request.name(), request.description(),
                request.priceInCents(), request.stock(), request.imageKey());
        products.save(product);
        return product;
    }

    public Product setStock(String productId, int stock) {
        if (!products.setStock(productId, stock)) {
            throw notFound(productId);
        }
        return get(productId);
    }

    private static DomainException notFound(String productId) {
        return new DomainException(ErrorCode.PRODUCT_NOT_FOUND, "Product " + productId + " does not exist.");
    }
}
