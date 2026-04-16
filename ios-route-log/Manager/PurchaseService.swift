//
//  PurchaseService.swift
//  ios-route-log (MoveLog)
//
//  App Store 課金（買い切りプレミアム）の管理サービス。
//  - isPremium: 購入済みかどうか
//  - isTestMode: DEBUG ビルドのみ有効。設定画面からオン/オフできる
//  - canUseAllIntervals: isPremium || isTestMode のとき true
//

import StoreKit
import Foundation
import Observation

@Observable
final class PurchaseService {

    // MARK: - Constants

    static let productID = "com.keisukearai.ios_route_log.premium"

    // MARK: - Published State

    private(set) var isPremium: Bool = false

    /// DEBUG ビルドのみ: テストモードのオン/オフ（UserDefaults に永続化）
    var isTestMode: Bool {
        get { _isTestMode }
        set {
            _isTestMode = newValue
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: "debugTestMode")
            #endif
        }
    }

    // MARK: - Private State

    private var _isTestMode: Bool = {
        #if DEBUG
        // DEBUG ビルドはデフォルトで true（実機テスト時にプレミアム扱い）
        // 設定画面のトグルで false に切り替えれば無課金の挙動を確認できる
        let stored = UserDefaults.standard.object(forKey: "debugTestMode")
        return stored == nil ? true : UserDefaults.standard.bool(forKey: "debugTestMode")
        #else
        return false
        #endif
    }()

    private var listenerTask: Task<Void, Never>?

    // MARK: - Computed

    /// 全インターバルを選択可能かどうか（プレミアム購入済み or テストモード）
    var canUseAllIntervals: Bool {
        isPremium || isTestMode
    }

    // MARK: - Init / Deinit

    init() {
        listenerTask = Task {
            await checkCurrentEntitlements()
            await listenForTransactions()
        }
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - Public API

    func purchase() async throws {
        let products = try await Product.products(for: [Self.productID])
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            isPremium = true
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await checkCurrentEntitlements()
    }

    func loadProduct() async -> Product? {
        try? await Product.products(for: [Self.productID]).first
    }

    // MARK: - Private

    private func checkCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                isPremium = true
                return
            }
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                if transaction.productID == Self.productID {
                    isPremium = transaction.revocationDate == nil
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let value):
            return value
        }
    }

    // MARK: - Errors

    enum PurchaseError: LocalizedError {
        case productNotFound
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "商品が見つかりませんでした。"
            case .failedVerification:
                return "購入の確認に失敗しました。"
            }
        }
    }
}
