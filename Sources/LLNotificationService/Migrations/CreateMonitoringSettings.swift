import Fluent

struct CreateMonitoringSettings: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(MonitoringSettings.schema)
            .id()
            .field("polling_interval_seconds", .int, .required)
            .field("balance_threshold", .double, .required)
            .field("notify_on_balance_below", .bool, .required)
            .field("notify_on_balance_above", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: any Database) async throws {
        try await database.schema(MonitoringSettings.schema).delete()
    }
}

