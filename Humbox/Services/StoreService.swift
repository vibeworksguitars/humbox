import StoreKit

@MainActor
final class StoreService: ObservableObject {
    @Published var isPro: Bool = false
    @Published var products: [Product] = []
    @Published var purchaseError: String?

    static let freeRecordingCap = 10

    static let productIDs = [
        "com.humbox.app.pro.monthly",
        "com.humbox.app.pro.yearly",
    ]

    private var transactionListener: Task<Void, Never>?

    init() {
        // Listen for transactions that arrive outside the app (e.g. renewals,
        // purchases made on another device) for the lifetime of the service.
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load

    func load() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchProducts() }
            group.addTask { await self.refreshEntitlement() }
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: - Private

    private func fetchProducts() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
        // Sort: monthly first, then yearly
        products.sort { $0.price < $1.price }
    }

    private func refreshEntitlement() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               Self.productIDs.contains(tx.productID),
               tx.revocationDate == nil {
                hasPro = true
                break
            }
        }
        isPro = hasPro
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        if case .verified(let tx) = result {
            await tx.finish()
            await refreshEntitlement()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }
}

// MARK: - Convenience

extension StoreService {
    var monthly: Product? { products.first { $0.id.hasSuffix("monthly") } }
    var yearly: Product?  { products.first { $0.id.hasSuffix("yearly") } }
}
