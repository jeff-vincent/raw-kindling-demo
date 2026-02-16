package com.store.orders;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;

@SpringBootApplication
@RestController
public class OrdersApplication {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private RabbitTemplate rabbitTemplate;

    public static void main(String[] args) {
        SpringApplication.run(OrdersApplication.class, args);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok", "service", "orders");
    }

    @GetMapping("/orders")
    public List<Order> listOrders() {
        return orderRepository.findAll();
    }

    @PostMapping("/orders")
    public ResponseEntity<Order> createOrder(@RequestBody CreateOrderRequest request) {
        Order order = new Order();
        order.setUserId(request.userId());
        order.setProductId(request.productId());
        order.setQuantity(request.quantity());
        order.setTotalPrice(request.totalPrice());
        order.setStatus("PENDING");
        order.setCreatedAt(Instant.now());
        order = orderRepository.save(order);

        rabbitTemplate.convertAndSend("orders.exchange", "order.created",
                Map.of("orderId", order.getId(), "userId", order.getUserId(),
                        "totalPrice", order.getTotalPrice().toString()));

        return ResponseEntity.status(201).body(order);
    }

    @RabbitListener(queues = "orders.payment.completed")
    public void handlePaymentCompleted(Map<String, Object> message) {
        Long orderId = ((Number) message.get("orderId")).longValue();
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus("PAID");
            orderRepository.save(order);
        });
    }

    public record CreateOrderRequest(String userId, Long productId, int quantity, BigDecimal totalPrice) {}

    @Entity
    @Table(name = "orders")
    public static class Order {
        @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
        private Long id;
        private String userId;
        private Long productId;
        private int quantity;
        private BigDecimal totalPrice;
        private String status;
        private Instant createdAt;

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
        public Long getProductId() { return productId; }
        public void setProductId(Long productId) { this.productId = productId; }
        public int getQuantity() { return quantity; }
        public void setQuantity(int quantity) { this.quantity = quantity; }
        public BigDecimal getTotalPrice() { return totalPrice; }
        public void setTotalPrice(BigDecimal totalPrice) { this.totalPrice = totalPrice; }
        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
        public Instant getCreatedAt() { return createdAt; }
        public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    }

    public interface OrderRepository extends org.springframework.data.jpa.repository.JpaRepository<Order, Long> {}
}
