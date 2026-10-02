package dev.orderflow.application.port;

import dev.orderflow.domain.Product;

import java.util.List;
import java.util.Optional;

public interface ProductRepository {

    List<Product> findAll();

    Optional<Product> findById(String id);

    void save(Product product);

    /**
     * Atomically takes {@code quantity} units from the product's stock.
     *
     * @return {@code false} when the product does not have enough stock (nothing is changed)
     */
    boolean reserveStock(String productId, int quantity);

    /** Gives {@code quantity} units back to the product's stock. */
    void releaseStock(String productId, int quantity);

    /**
     * Overwrites the stock of an existing product.
     *
     * @return {@code false} when the product does not exist
     */
    boolean setStock(String productId, int stock);
}
