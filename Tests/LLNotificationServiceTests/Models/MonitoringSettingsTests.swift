@testable import LLNotificationService
import VaporTesting
import Testing
import Fluent

@Suite("MonitoringSettings Model Tests", .serialized)
struct MonitoringSettingsTests {
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
    
    @Test("MonitoringSettings can be created and saved")
    func createSettings() async throws {
        try await withApp { app in
            // Arrange
            let settings = MonitoringSettings(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: false
            )
            
            // Act
            try await settings.save(on: app.db)
            
            // Assert
            let fetched = try await MonitoringSettings.query(on: app.db).first()
            #expect(fetched != nil)
            #expect(fetched?.pollingIntervalSeconds == 60)
            #expect(fetched?.balanceThreshold == 1000.0)
            #expect(fetched?.notifyOnBalanceBelow == true)
            #expect(fetched?.notifyOnBalanceAbove == false)
        }
    }
    
    @Test("Can retrieve current monitoring settings")
    func getCurrentSettings() async throws {
        try await withApp { app in
            // Arrange - create settings
            let settings = MonitoringSettings(
                pollingIntervalSeconds: 30,
                balanceThreshold: 500.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: true
            )
            try await settings.save(on: app.db)
            
            // Act
            let current = try await MonitoringSettings.getCurrent(on: app.db)
            
            // Assert
            #expect(current != nil)
            #expect(current?.pollingIntervalSeconds == 30)
            #expect(current?.balanceThreshold == 500.0)
        }
    }
    
    @Test("Can update existing settings")
    func updateSettings() async throws {
        try await withApp { app in
            // Arrange
            let settings = MonitoringSettings(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: false
            )
            try await settings.save(on: app.db)
            
            // Act
            settings.pollingIntervalSeconds = 120
            settings.balanceThreshold = 2000.0
            try await settings.save(on: app.db)
            
            // Assert
            let fetched = try await MonitoringSettings.query(on: app.db).first()
            #expect(fetched?.pollingIntervalSeconds == 120)
            #expect(fetched?.balanceThreshold == 2000.0)
        }
    }
    
    @Test("Only one settings record should exist")
    func singletonSettings() async throws {
        try await withApp { app in
            // Arrange - create first settings
            let settings1 = MonitoringSettings(
                pollingIntervalSeconds: 60,
                balanceThreshold: 1000.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: false
            )
            try await settings1.save(on: app.db)
            
            // Act - update settings (should replace, not create new)
            try await MonitoringSettings.updateOrCreate(
                pollingIntervalSeconds: 30,
                balanceThreshold: 500.0,
                notifyOnBalanceBelow: true,
                notifyOnBalanceAbove: true,
                on: app.db
            )
            
            // Assert - should only have 1 record
            let allSettings = try await MonitoringSettings.query(on: app.db).all()
            #expect(allSettings.count == 1)
            
            // And it should have the updated values
            let current = try await MonitoringSettings.getCurrent(on: app.db)
            #expect(current?.pollingIntervalSeconds == 30)
            #expect(current?.balanceThreshold == 500.0)
        }
    }
    
    @Test("Default settings when none exist")
    func defaultSettings() async throws {
        try await withApp { app in
            // Act
            let current = try await MonitoringSettings.getCurrent(on: app.db)
            
            // Assert - should return nil or create default
            // For now, we expect nil
            #expect(current == nil)
        }
    }
}

