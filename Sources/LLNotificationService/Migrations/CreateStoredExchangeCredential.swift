import Fluent

/*
 define a Model for your data structure.
 create a Migration to build the corresponding table.
 register migrations in configure.swift:
 */

struct CreateStoredExchangeCredential: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(StoredExchangeCredential.schema)
            .id()
            .field("exchange_name", .string, .required)
            .field("wallet_type", .string, .required)
            .field("api_key", .string, .required)
            .field("encrypted_secret", .string, .required)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "exchange_name", "wallet_type") // Only one credential per exchange+wallet combination
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(StoredExchangeCredential.schema).delete()
    }
}

