@testable import LLNotificationService
import VaporTesting
import Testing
import Fluent
import LLCore

// MARK: - Mock Dependencies

/// Mock balance fetcher for testing
class MockBalanceFetcher: BalanceFetcher, @unchecked Sendable {
    var mockWalletData: WalletData?
    var shouldThrowError = false
    var fetchCallCount = 0
    
    func fetchBalance(credentials: Credentials, exchangeType: ExchangeType) async throws -> WalletData {
        fetchCallCount += 1
        
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        
        guard let data = mockWalletData else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock data"])
        }
        
        return data
    }
}

/// Mock notification sender for testing
class MockNotificationSender: NotificationSender, @unchecked Sendable {
    var sentNotifications: [(balance: Double, threshold: Double, isBelow: Bool)] = []
    var shouldThrowError = false
    
    func sendBalanceAlert(balance: Double, threshold: Double, isBelow: Bool) async throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 3, userInfo: nil)
        }
        
        sentNotifications.append((balance: balance, threshold: threshold, isBelow: isBelow))
    }
    
    func reset() {
        sentNotifications.removeAll()
    }
}

// MARK: - Tests

@Suite("WalletMonitorService Tests", .serialized)
struct WalletMonitorServiceTests {
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
    
    @Test("Can fetch balance successfully")
    func fetchBalance() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            mockFetcher.mockWalletData = WalletData(
                totalEquity: "5000.50",
                walletBalance: "5000.50"
            )
            
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender
            )
            
            // Create test data
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_key",
                encryptedSecret: "test_secret",
                isActive: true
            )
            try await credential.save(on: app.db)
            
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: false,
                notifyOnBalanceAbove: false,
                on: app.db
            )
            
            // Act
            let result = try await service.checkBalance()
            
            // Assert
            #expect(result.balance == 5000.50)
            #expect(mockFetcher.fetchCallCount == 1)
        }
    }
    
    @Test("Sends notification when balance below threshold")
    func notifyBelowThreshold() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            mockFetcher.mockWalletData = WalletData(
                totalEquity: "500.00",
                walletBalance: "500.00"
            )
            
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender
            )
            
            // Create test data
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_key",
                encryptedSecret: "test_secret",
                isActive: true
            )
            try await credential.save(on: app.db)
            
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: false,
                on: app.db
            )
            
            // Act
            let result = try await service.checkBalance()
            
            // Assert
            #expect(result.balance == 500.0)
            #expect(result.notificationSent == true)
            #expect(mockSender.sentNotifications.count == 1)
            #expect(mockSender.sentNotifications[0].isBelow == true)
        }
    }
    
    @Test("Sends notification when balance above threshold")
    func notifyAboveThreshold() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            mockFetcher.mockWalletData = WalletData(
                totalEquity: "1500.00",
                walletBalance: "1500.00"
            )
            
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender
            )
            
            // Create test data
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_key",
                encryptedSecret: "test_secret",
                isActive: true
            )
            try await credential.save(on: app.db)
            
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: false,
                notifyOnBalanceAbove: true,
                on: app.db
            )
            
            // Act
            let result = try await service.checkBalance()
            
            // Assert
            #expect(result.balance == 1500.0)
            #expect(result.notificationSent == true)
            #expect(mockSender.sentNotifications.count == 1)
            #expect(mockSender.sentNotifications[0].isBelow == false)
        }
    }
    
    @Test("Does not send notification when within threshold")
    func noNotificationWithinThreshold() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            mockFetcher.mockWalletData = WalletData(
                totalEquity: "1000.00",
                walletBalance: "1000.00"
            )
            
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender
            )
            
            // Create test data
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_key",
                encryptedSecret: "test_secret",
                isActive: true
            )
            try await credential.save(on: app.db)
            
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: true,
                on: app.db
            )
            
            // Act
            let result = try await service.checkBalance()
            
            // Assert
            #expect(result.balance == 1000.0)
            #expect(result.notificationSent == false)
            #expect(mockSender.sentNotifications.count == 0)
        }
    }
    
    @Test("Debounces notifications - does not send duplicate within cooldown period")
    func debounceNotifications() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            mockFetcher.mockWalletData = WalletData(
                totalEquity: "500.00",
                walletBalance: "500.00"
            )
            
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender,
                notificationCooldownSeconds: 60 // 1 minute cooldown
            )
            
            // Create test data
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_key",
                encryptedSecret: "test_secret",
                isActive: true
            )
            try await credential.save(on: app.db)
            
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 10,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: false,
                on: app.db
            )
            
            // Act - check balance multiple times quickly
            let result1 = try await service.checkBalance()
            let result2 = try await service.checkBalance()
            let result3 = try await service.checkBalance()
            
            // Assert - only first notification should be sent
            #expect(result1.notificationSent == true)
            #expect(result2.notificationSent == false)
            #expect(result3.notificationSent == false)
            #expect(mockSender.sentNotifications.count == 1)
        }
    }
    
    @Test("Throws error when no active credentials")
    func errorNoCredentials() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender
            )
            
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: false,
                on: app.db
            )
            
            // Act & Assert
            await #expect(throws: WalletMonitorError.noActiveCredentials) {
                try await service.checkBalance()
            }
        }
    }
    
    @Test("Uses default settings when none exist")
    func defaultSettings() async throws {
        try await withApp { app in
            // Arrange
            let mockFetcher = MockBalanceFetcher()
            mockFetcher.mockWalletData = WalletData(
                totalEquity: "5000.00",
                walletBalance: "5000.00"
            )
            
            let mockSender = MockNotificationSender()
            
            let service = WalletMonitorService(
                database: app.db,
                balanceFetcher: mockFetcher,
                notificationSender: mockSender
            )
            
            // Create credential but NO settings
            let credential = StoredExchangeCredential(
                platform: .binance(walletType: .futures),
                apiKey: "test_key",
                encryptedSecret: "test_secret",
                isActive: true
            )
            try await credential.save(on: app.db)
            
            // Act
            let result = try await service.checkBalance()
            
            // Assert - should use default threshold (e.g., 0)
            #expect(result.balance == 5000.0)
            #expect(result.threshold == 0.0) // Default threshold
        }
    }
}

