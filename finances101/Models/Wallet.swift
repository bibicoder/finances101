import Foundation
import SwiftData
import SwiftUI

enum WalletType: String, Codable, CaseIterable {
    case cash = "Cash"
    case card = "Card"
    case savings = "Savings"
    case investment = "Investment"
    case crypto = "Crypto"
    case other = "Other"

    var icon: String {
        switch self {
        case .cash:       return "banknote.fill"
        case .card:       return "creditcard.fill"
        case .savings:    return "building.columns.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .crypto:     return "bitcoinsign.circle.fill"
        case .other:      return "wallet.pass.fill"
        }
    }
}

/// Supported on-chain wallets tracked by public address (read-only, no login).
/// Covers native coins AND stablecoin tokens (USDT/USDC) on their networks.
/// Each has a free public balance API and a CoinGecko price id.
enum CryptoChain: String, Codable, CaseIterable {
    // Native coins
    case bitcoin   = "BTC"
    case ethereum  = "ETH"
    case litecoin  = "LTC"
    case dogecoin  = "DOGE"
    case solana    = "SOL"
    case bnb       = "BNB"
    case polygon   = "MATIC"
    case avalanche = "AVAX"
    case tron      = "TRX"
    // Stablecoin tokens (network-specific contracts)
    case usdtEth   = "USDT-ERC20"
    case usdtBsc   = "USDT-BEP20"
    case usdtTron  = "USDT-TRC20"
    case usdcEth   = "USDC-ERC20"
    case usdcBsc   = "USDC-BEP20"

    var displayName: String {
        switch self {
        case .bitcoin:   return "Bitcoin"
        case .ethereum:  return "Ethereum"
        case .litecoin:  return "Litecoin"
        case .dogecoin:  return "Dogecoin"
        case .solana:    return "Solana"
        case .bnb:       return "BNB (BSC)"
        case .polygon:   return "Polygon"
        case .avalanche: return "Avalanche"
        case .tron:      return "Tron (TRX)"
        case .usdtEth:   return "USDT — Ethereum (ERC-20)"
        case .usdtBsc:   return "USDT — BNB (BEP-20)"
        case .usdtTron:  return "USDT — Tron (TRC-20)"
        case .usdcEth:   return "USDC — Ethereum (ERC-20)"
        case .usdcBsc:   return "USDC — BNB (BEP-20)"
        }
    }

    /// Short ticker for chips/labels (BTC, USDT, …).
    var ticker: String {
        switch self {
        case .usdtEth, .usdtBsc, .usdtTron: return "USDT"
        case .usdcEth, .usdcBsc:            return "USDC"
        default:                            return rawValue
        }
    }

    /// CoinGecko coin id used to fetch the USD price.
    var priceId: String {
        switch self {
        case .bitcoin:                      return "bitcoin"
        case .ethereum:                     return "ethereum"
        case .litecoin:                     return "litecoin"
        case .dogecoin:                     return "dogecoin"
        case .solana:                       return "solana"
        case .bnb:                          return "binancecoin"
        case .polygon:                      return "matic-network"
        case .avalanche:                    return "avalanche-2"
        case .tron:                         return "tron"
        case .usdtEth, .usdtBsc, .usdtTron: return "tether"
        case .usdcEth, .usdcBsc:            return "usd-coin"
        }
    }

    /// EVM JSON-RPC endpoint for the underlying network (native coin or token).
    var evmRPC: String? {
        switch self {
        case .ethereum, .usdtEth, .usdcEth: return "https://ethereum-rpc.publicnode.com"
        case .bnb, .usdtBsc, .usdcBsc:      return "https://bsc-dataseed.binance.org"
        case .polygon:                      return "https://polygon-rpc.com"
        case .avalanche:                    return "https://api.avax.network/ext/bc/C/rpc"
        default:                            return nil
        }
    }

    /// ERC-20/BEP-20 contract address — non-nil means "read this token via balanceOf".
    var tokenContract: String? {
        switch self {
        case .usdtEth:  return "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        case .usdcEth:  return "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        case .usdtBsc:  return "0x55d398326f99059fF775485246999027B3197955"
        case .usdcBsc:  return "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d"
        default:        return nil
        }
    }

    /// USDT-TRC20 contract on Tron (read via TronGrid trc20 balances).
    var tronTokenContract: String? {
        switch self {
        case .usdtTron: return "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        default:        return nil
        }
    }

    /// Decimal places used to scale the raw on-chain integer into a human amount.
    var decimals: Int {
        switch self {
        case .bitcoin, .litecoin:           return 8
        case .solana:                       return 9
        case .tron, .usdtTron:              return 6
        case .usdtEth, .usdcEth:            return 6      // ERC-20 USDT/USDC use 6
        case .usdtBsc, .usdcBsc:            return 18     // BEP-20 variants use 18
        default:                            return 18     // EVM native coins
        }
    }

    var isTron: Bool { self == .tron || self == .usdtTron }

    /// Esplora-style UTXO explorers (Blockstream API shape, balance in 1e8 base units).
    var esploraBase: String? {
        switch self {
        case .bitcoin:  return "https://blockstream.info/api"
        case .litecoin: return "https://litecoinspace.org/api"
        default:        return nil
        }
    }
}

@Model
final class Wallet {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var name: String = ""
    var type: WalletType = WalletType.card
    var initialBalance: Decimal = 0
    var colorHex: String = "7C3AED"
    var isDefault: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    // Crypto-by-address tracking (read-only). All optional — CloudKit-safe.
    var cryptoAddress: String?
    var cryptoChain: String?          // CryptoChain.rawValue ("BTC"/"ETH")
    var cryptoAmount: Decimal?        // amount in coin (e.g. 0.052 BTC)
    var cryptoBalanceUSD: Decimal?    // cached USD value
    var cryptoSyncedAt: Date?

    var iconName: String { type.icon }
    var isCrypto: Bool { type == .crypto && cryptoAddress != nil }

    init(
        id: UUID = UUID(),
        name: String,
        type: WalletType = .card,
        initialBalance: Decimal = 0,
        colorHex: String = "7C3AED",
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

@Model
final class WalletTransfer {
    // Inline defaults are required for CloudKit-backed SwiftData stores
    var id: UUID = UUID()
    var fromWalletId: UUID = UUID()
    var toWalletId: UUID = UUID()
    var amount: Decimal = 0
    var date: Date = Date()
    var note: String?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        fromWalletId: UUID,
        toWalletId: UUID,
        amount: Decimal,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.fromWalletId = fromWalletId
        self.toWalletId = toWalletId
        self.amount = amount
        self.date = date
        self.note = note
        self.createdAt = Date()
    }
}
