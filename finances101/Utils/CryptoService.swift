import Foundation

/// Read-only crypto tracking by public address — no logins, no keys.
/// Balances come from public blockchain APIs, prices from CoinGecko.
enum CryptoService {

    enum CryptoError: LocalizedError {
        case invalidAddress
        case badResponse

        var errorDescription: String? {
            switch self {
            case .invalidAddress: return "Invalid wallet address"
            case .badResponse:    return "Could not read balance — try again later"
            }
        }
    }

    /// Refreshes coin amount + USD value for every crypto wallet. Best-effort:
    /// individual failures are logged, last known values are kept.
    @MainActor
    static func refreshAll(_ wallets: [Wallet]) async {
        let cryptoWallets = wallets.filter(\.isCrypto)
        guard !cryptoWallets.isEmpty else { return }

        let prices = (try? await fetchPricesUSD()) ?? [:]

        for wallet in cryptoWallets {
            guard let address = wallet.cryptoAddress,
                  let chainRaw = wallet.cryptoChain,
                  let chain = CryptoChain(rawValue: chainRaw) else { continue }
            do {
                let amount = try await fetchBalance(chain: chain, address: address)
                wallet.cryptoAmount = amount
                if let price = prices[chain] {
                    wallet.cryptoBalanceUSD = (amount * price).rounded2dp()
                }
                wallet.cryptoSyncedAt = Date()
            } catch {
                print("[Crypto] \(wallet.name) (\(chainRaw)) refresh failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Balances

    static func fetchBalance(chain: CryptoChain, address: String) async throws -> Decimal {
        if chain.isTron {
            return try await fetchTronBalance(chain: chain, address: address)
        }
        if let rpc = chain.evmRPC {
            // Token (USDT/USDC) → balanceOf; native coin → eth_getBalance
            if let contract = chain.tokenContract {
                return try await fetchEVMTokenBalance(rpcURL: rpc, contract: contract, address: address, decimals: chain.decimals)
            }
            return try await fetchEVMBalance(rpcURL: rpc, address: address)
        }
        if let base = chain.esploraBase {
            return try await fetchEsploraBalance(apiBase: base, address: address)
        }
        switch chain {
        case .dogecoin: return try await fetchDogecoinBalance(address: address)
        case .solana:   return try await fetchSolanaBalance(address: address)
        default:        throw CryptoError.badResponse
        }
    }

    /// Esplora/Blockstream API (BTC, LTC): balance = funded − spent, in 1e8 base units.
    private static func fetchEsploraBalance(apiBase: String, address: String) async throws -> Decimal {
        guard let url = URL(string: "\(apiBase)/address/\(address)") else {
            throw CryptoError.invalidAddress
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stats = json["chain_stats"] as? [String: Any],
              let funded = stats["funded_txo_sum"] as? Int64,
              let spent = stats["spent_txo_sum"] as? Int64 else {
            throw CryptoError.badResponse
        }
        return Decimal(funded - spent) / 100_000_000
    }

    /// Any EVM chain (ETH, BNB, Polygon, Avalanche): eth_getBalance returns wei as hex.
    private static func fetchEVMBalance(rpcURL: String, address: String) async throws -> Decimal {
        guard let url = URL(string: rpcURL) else { throw CryptoError.badResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1,
            "method": "eth_getBalance",
            "params": [address, "latest"],
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hex = json["result"] as? String, hex.hasPrefix("0x"),
              let wei = decimalFromHex(String(hex.dropFirst(2))) else {
            throw CryptoError.badResponse
        }
        return wei / Decimal(string: "1000000000000000000")!  // wei → coin (18 decimals)
    }

    /// ERC-20 / BEP-20 token balance via eth_call to the contract's balanceOf(address).
    private static func fetchEVMTokenBalance(rpcURL: String, contract: String, address: String, decimals: Int) async throws -> Decimal {
        guard let url = URL(string: rpcURL) else { throw CryptoError.badResponse }
        // balanceOf selector (0x70a08231) + the address left-padded to 32 bytes
        let cleanAddr = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        guard cleanAddr.count == 40 else { throw CryptoError.invalidAddress }
        let data = "0x70a08231" + String(repeating: "0", count: 24) + cleanAddr.lowercased()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1,
            "method": "eth_call",
            "params": [["to": contract, "data": data], "latest"],
        ])
        let (respData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
              let hex = json["result"] as? String, hex.hasPrefix("0x"),
              let raw = decimalFromHex(String(hex.dropFirst(2))) else {
            throw CryptoError.badResponse
        }
        return raw / pow(Decimal(10), decimals)
    }

    /// Tron via TronGrid: native TRX from `balance` (sun, 1e6); USDT-TRC20 from the
    /// `trc20` token list keyed by contract address (1e6).
    private static func fetchTronBalance(chain: CryptoChain, address: String) async throws -> Decimal {
        guard let url = URL(string: "https://api.trongrid.io/v1/accounts/\(address)") else {
            throw CryptoError.invalidAddress
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]], let account = arr.first else {
            // Empty/unused Tron account returns no data — treat as zero, not an error
            return 0
        }

        if let contract = chain.tronTokenContract {
            let tokens = account["trc20"] as? [[String: String]] ?? []
            for entry in tokens {
                if let raw = entry[contract], let value = Decimal(string: raw) {
                    return value / pow(Decimal(10), chain.decimals)
                }
            }
            return 0
        }

        let sun = (account["balance"] as? NSNumber)?.int64Value ?? 0
        return Decimal(sun) / pow(Decimal(10), chain.decimals)
    }

    /// Dogechain API: returns balance already in DOGE as a string.
    private static func fetchDogecoinBalance(address: String) async throws -> Decimal {
        guard let url = URL(string: "https://dogechain.info/api/v1/address/balance/\(address)") else {
            throw CryptoError.invalidAddress
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let balanceStr = json["balance"] as? String,
              let balance = Decimal(string: balanceStr) else {
            throw CryptoError.badResponse
        }
        return balance
    }

    /// Solana JSON-RPC getBalance: returns lamports (1e9 per SOL).
    private static func fetchSolanaBalance(address: String) async throws -> Decimal {
        guard let url = URL(string: "https://api.mainnet-beta.solana.com") else {
            throw CryptoError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1,
            "method": "getBalance",
            "params": [address],
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let lamports = result["value"] as? Int64 else {
            throw CryptoError.badResponse
        }
        return Decimal(lamports) / 1_000_000_000
    }

    /// Hex → Decimal without UInt64 overflow (wei values exceed UInt64 above ~18.4 ETH).
    private static func decimalFromHex(_ hex: String) -> Decimal? {
        var result = Decimal(0)
        for char in hex.lowercased() {
            guard let digit = char.hexDigitValue else { return nil }
            result = result * 16 + Decimal(digit)
        }
        return result
    }

    // MARK: - Prices

    /// CoinGecko free endpoint — no API key required. Prices every supported chain at once.
    static func fetchPricesUSD() async throws -> [CryptoChain: Decimal] {
        let ids = Set(CryptoChain.allCases.map(\.priceId)).joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd") else {
            throw CryptoError.badResponse
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else {
            throw CryptoError.badResponse
        }
        var prices: [CryptoChain: Decimal] = [:]
        for chain in CryptoChain.allCases {
            if let usd = json[chain.priceId]?["usd"] {
                prices[chain] = Decimal(money: usd)
            }
        }
        return prices
    }
}

private extension Decimal {
    func rounded2dp() -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .bankers)
        return result
    }
}
