import Foundation

/// Result of a balance check operation
struct BalanceCheckResult: Sendable {
    /// The current balance
    let balance: Double
    
    /// The threshold being monitored
    let threshold: Double
    
    /// Whether a notification was sent
    let notificationSent: Bool
    
    /// When the check was performed
    let timestamp: Date
}

/// Errors that can occur during wallet monitoring
enum WalletMonitorError: Error, Equatable {
    case noActiveCredentials
    case noSettings
    case invalidBalance
    case apiError(String)
    
    static func == (lhs: WalletMonitorError, rhs: WalletMonitorError) -> Bool {
        switch (lhs, rhs) {
        case (.noActiveCredentials, .noActiveCredentials),
             (.noSettings, .noSettings),
             (.invalidBalance, .invalidBalance):
            return true
        case (.apiError(let lhsMsg), .apiError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

