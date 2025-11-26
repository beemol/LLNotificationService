@testable import LLNotificationService
import VaporTesting
import Testing
import Fluent
import LLCore

@Suite("StoredExchangeCredential Model Tests", .serialized)
struct StoredExchangeCredentialTests {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
    
    @Test("StoredExchangeCredential can be created and saved")
    func createCredential() async throws {
        try await withApp { app in
            // Arrange
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_api_key",
                encryptedSecret: "encrypted_secret_data",
                isActive: false
            )
            
            // Act
            try await credential.save(on: app.db)
            
            // Assert
            let fetched = try await StoredExchangeCredential.query(on: app.db).first()
            #expect(fetched != nil)
            #expect(fetched?.platform == .binance(walletType: .futures))
            #expect(fetched?.apiKey == "test_api_key")
            #expect(fetched?.encryptedSecret == "encrypted_secret_data")
            #expect(fetched?.isActive == false)
        }
    }
    
    @Test("Only one credential can be active at a time")
    func onlyOneActiveCredential() async throws {
        try await withApp { app in
            // Arrange
            let credential1 = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "key1",
                encryptedSecret: "secret1",
                isActive: true
            )
            let credential2 = StoredExchangeCredential(
                platform: .kucoin(walletType: .futures),
                apiKey: "key2",
                encryptedSecret: "secret2",
                isActive: false
            )
            
            try await credential1.save(on: app.db)
            try await credential2.save(on: app.db)
            
            // Act - activate credential2 (should deactivate credential1)
            try await credential2.activate(on: app.db)
            
            // Assert - only credential2 should be active
            let activeCredentials = try await StoredExchangeCredential.query(on: app.db)
                .filter(\.$isActive == true)
                .all()
            
            #expect(activeCredentials.count == 1)
            #expect(activeCredentials.first?.platform == .kucoin(walletType: .futures))
        }
    }
    
    @Test("Can find active credential")
    func findActiveCredential() async throws {
        try await withApp { app in
            // Arrange
            let inactive = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "key1",
                encryptedSecret: "secret1",
                isActive: false
            )
            let active = StoredExchangeCredential(
                platform: .kucoin(walletType: .futures),
                apiKey: "key2",
                encryptedSecret: "secret2",
                isActive: true
            )
            
            try await inactive.save(on: app.db)
            try await active.save(on: app.db)
            
            // Act
            let found = try await StoredExchangeCredential.findActive(on: app.db)
            
            // Assert
            #expect(found != nil)
            #expect(found?.platform == .kucoin(walletType: .futures))
            #expect(found?.isActive == true)
        }
    }
    
    @Test("Can update existing credential for same platform")
    func updateExistingCredential() async throws {
        try await withApp { app in
            // Arrange
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "old_key",
                encryptedSecret: "old_secret",
                isActive: false
            )
            try await credential.save(on: app.db)
            
            // Act
            let updated = try await StoredExchangeCredential.findOrCreate(
                platform: .binance(walletType: .futures),
                on: app.db
            )
            updated.apiKey = "new_key"
            updated.encryptedSecret = "new_secret"
            try await updated.save(on: app.db)
            
            // Assert
            let all = try await StoredExchangeCredential.query(on: app.db).all()
            #expect(all.count == 1) // Should not create duplicate
            #expect(all.first?.apiKey == "new_key")
            #expect(all.first?.encryptedSecret == "new_secret")
        }
    }
}

