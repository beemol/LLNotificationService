import Fluent
import Vapor
import LLCore

/// Stores encrypted exchange API credentials
final class StoredExchangeCredential: Model, @unchecked Sendable {
    static let schema = "stored_exchange_credentials"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "exchange_name")
    var exchangeName: String
    
    @Field(key: "wallet_type")
    var walletType: String
    
    @Field(key: "api_key")
    var apiKey: String
    
    @Field(key: "encrypted_secret")
    var encryptedSecret: String
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        platform: ExchangeType,
        apiKey: String,
        encryptedSecret: String,
        isActive: Bool
    ) {
        self.id = id
        self.exchangeName = platform.exchangeName.rawValue
        self.walletType = platform.walletType.rawValue
        self.apiKey = apiKey
        self.encryptedSecret = encryptedSecret
        self.isActive = isActive
    }
    
    /// Convenience computed property to get ExchangeType
    var platform: ExchangeType {
        get {
            guard let name = ExchangeName(rawValue: exchangeName),
                  let wallet = WalletType(rawValue: walletType) else {
                // Default fallback
                return .binance(walletType: .spot)
            }
            return ExchangeType.make(name, wallet: wallet)
        }
        set {
            exchangeName = newValue.exchangeName.rawValue
            walletType = newValue.walletType.rawValue
        }
    }
}

// MARK: - Query Helpers
extension StoredExchangeCredential {
    /// Find the currently active credential
    static func findActive(on database: any Database) async throws -> StoredExchangeCredential? {
        try await StoredExchangeCredential.query(on: database)
            .filter(\.$isActive == true)
            .first()
    }
    
    /// Find existing credential for platform or create a new one
    static func findOrCreate(platform: ExchangeType, on database: any Database) async throws -> StoredExchangeCredential {
        let exchangeName = platform.exchangeName.rawValue
        let walletType = platform.walletType.rawValue
        
        if let existing = try await StoredExchangeCredential.query(on: database)
            .filter(\.$exchangeName == exchangeName)
            .filter(\.$walletType == walletType)
            .first() {
            return existing
        }
        
        return StoredExchangeCredential(
            platform: platform,
            apiKey: "",
            encryptedSecret: "",
            isActive: false
        )
    }
    
    /// Activate this credential and deactivate all others
    func activate(on database: any Database) async throws {
        // First deactivate all credentials
        try await StoredExchangeCredential.query(on: database)
            .set(\.$isActive, to: false)
            .update()
        
        // Then activate this one
        self.isActive = true
        try await self.save(on: database)
    }
}

