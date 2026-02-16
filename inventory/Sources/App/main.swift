import Vapor
import Fluent
import FluentPostgresDriver

final class InventoryItem: Model, Content {
    static let schema = "inventory_items"

    @ID(key: .id) var id: UUID?
    @Field(key: "product_id") var productId: Int
    @Field(key: "sku") var sku: String
    @Field(key: "quantity") var quantity: Int
    @Field(key: "warehouse") var warehouse: String
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(productId: Int, sku: String, quantity: Int, warehouse: String) {
        self.productId = productId
        self.sku = sku
        self.quantity = quantity
        self.warehouse = warehouse
    }
}

struct CreateInventoryItems: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("inventory_items")
            .id()
            .field("product_id", .int, .required)
            .field("sku", .string, .required)
            .field("quantity", .int, .required)
            .field("warehouse", .string, .required)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("inventory_items").delete()
    }
}

@main
struct App {
    static func main() async throws {
        var env = try Environment.detect()
        let app = Application(env)
        defer { app.shutdown() }

        let dbHost = Environment.get("DB_HOST") ?? "localhost"
        let dbPort = Environment.get("DB_PORT").flatMap(Int.init) ?? 5432
        let dbUser = Environment.get("DB_USER") ?? "postgres"
        let dbPass = Environment.get("DB_PASSWORD") ?? "postgres"
        let dbName = Environment.get("DB_NAME") ?? "inventory"

        app.databases.use(.postgres(
            hostname: dbHost,
            port: dbPort,
            username: dbUser,
            password: dbPass,
            database: dbName
        ), as: .psql)

        app.migrations.add(CreateInventoryItems())
        try await app.autoMigrate()

        app.get("health") { req in
            ["status": "ok", "service": "inventory"]
        }

        app.get("inventory") { req async throws -> [InventoryItem] in
            try await InventoryItem.query(on: req.db).all()
        }

        app.post("inventory") { req async throws -> InventoryItem in
            let item = try req.content.decode(InventoryItem.self)
            try await item.save(on: req.db)
            return item
        }

        app.patch("inventory", ":id", "adjust") { req async throws -> InventoryItem in
            guard let item = try await InventoryItem.find(req.parameters.get("id"), on: req.db) else {
                throw Abort(.notFound)
            }
            struct AdjustRequest: Content { let quantity: Int }
            let adjust = try req.content.decode(AdjustRequest.self)
            item.quantity += adjust.quantity
            try await item.save(on: req.db)
            return item
        }

        let port = Environment.get("PORT").flatMap(Int.init) ?? 3010
        app.http.server.configuration.port = port
        try await app.execute()
    }
}
