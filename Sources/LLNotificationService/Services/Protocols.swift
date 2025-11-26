import Foundation
import LLCore

/// Protocol for fetching wallet balance from exchanges
protocol BalanceFetcher: Sendable {
    /// Fetch wallet balance for given credentials and exchange type
    /// - Parameters:
    ///   - credentials: API credentials (key, secret, passphrase)
    ///   - exchangeType: The exchange and wallet type to query
    /// - Returns: WalletData containing balance information
    func fetchBalance(credentials: Credentials, exchangeType: ExchangeType) async throws -> WalletData
}

/// Protocol for sending notifications
protocol NotificationSender: Sendable {
    /// Send a balance alert notification
    /// - Parameters:
    ///   - balance: Current balance
    ///   - threshold: The threshold that was crossed
    ///   - isBelow: true if balance is below threshold, false if above
    func sendBalanceAlert(balance: Double, threshold: Double, isBelow: Bool) async throws
}

