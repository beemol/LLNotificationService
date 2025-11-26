import Fluent
import Vapor

/// Stores monitoring configuration settings
final class MonitoringSettings: Model, @unchecked Sendable {
    static let schema = "monitoring_settings"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "polling_interval_seconds")
    var pollingIntervalSeconds: Int
    
    @Field(key: "balance_threshold")
    var balanceThreshold: Double
    
    @Field(key: "notify_on_balance_below")
    var notifyOnBalanceBelow: Bool
    
    @Field(key: "notify_on_balance_above")
    var notifyOnBalanceAbove: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        pollingIntervalSeconds: Int,
        balanceThreshold: Double,
        notifyOnBalanceBelow: Bool,
        notifyOnBalanceAbove: Bool
    ) {
        self.id = id
        self.pollingIntervalSeconds = pollingIntervalSeconds
        self.balanceThreshold = balanceThreshold
        self.notifyOnBalanceBelow = notifyOnBalanceBelow
        self.notifyOnBalanceAbove = notifyOnBalanceAbove
    }
}

// MARK: - Query Helpers
extension MonitoringSettings {
    /// Get the current (most recent) monitoring settings
    static func getCurrent(on database: any Database) async throws -> MonitoringSettings? {
        try await MonitoringSettings.query(on: database)
            .sort(\.$createdAt, .descending)
            .first()
    }
}

