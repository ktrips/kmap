import CryptoKit
import FirebaseCore
import FirebaseFunctions
import Foundation
import StoreKit

/// Komap Plus の対象機能。無料でも一部だけ試せる機能は`freeLimit`で回数を持つ。
enum PlusFeature: String, Identifiable {
    /// 写真の追加（写真投稿・御朱印の写真の追加／変更・連携カメラからの取り込み）。
    case photo
    /// 場所の詳細（AIが作る、チェックポイントの由来やエピソードの解説）。
    case placeDetail
    /// 旅の動画の作成。
    case tripVideo
    /// AIの旅日記の作成（作成済みの旅日記は無料でも読める）。
    case travelJournal
    /// 初めて旅を保存した時に、一度だけ比較ページを見せる。
    case firstTrip

    var id: String { rawValue }

    /// 無料で使える回数。`placeDetail`は場所の数、`tripVideo`は旅の数で数える
    /// （同じ場所・同じ旅を開き直しても回数は減らない）。
    var freeLimit: Int {
        switch self {
        case .placeDetail: return 3
        case .tripVideo: return 1
        case .photo, .travelJournal, .firstTrip: return 0
        }
    }

    /// 比較ページを開いた理由として、冒頭に出す一文。
    var paywallMessage: String {
        switch self {
        case .photo:
            return "写真を残すのは Komap Plus の機能です。御朱印や歩いた道の写真を、旅の記録と一緒に残せます。"
        case .placeDetail:
            return "場所の詳細は、無料で\(freeLimit)か所まで読めます。Plus なら、どの場所でも昔の出来事を読めます。"
        case .tripVideo:
            return "旅の動画は、無料で\(freeLimit)本まで作れます。Plus なら、すべての旅を動画にできます。"
        case .travelJournal:
            return "AIの旅日記は Komap Plus の機能です。巡った御朱印や写真、感想から、その日の旅を一編の日記にまとめます。"
        case .firstTrip:
            return "初めての時空旅、おつかれさまでした。Plus なら、写真や動画でこの旅をもっと残せます。"
        }
    }
}

/// 無料で試せる回数の記録。アプリを入れ直しても回数が戻らないよう、Keychainに保存する。
/// 回数は「使った場所・旅のID」の集合で持ち、同じ場所・旅なら何度開いても1回と数える。
enum PlusFreeUsage {
    private static func key(for feature: PlusFeature) -> String { "plusFreeUsage.\(feature.rawValue)" }

    static func usedIDs(for feature: PlusFeature) -> Set<String> {
        guard let raw = KeychainStore.shared.get(forKey: key(for: feature)),
              let data = raw.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(ids)
    }

    static func remaining(for feature: PlusFeature) -> Int {
        max(0, feature.freeLimit - usedIDs(for: feature).count)
    }

    /// その場所・旅で、無料枠を使ってよいか（既に使った場所・旅か、まだ枠が残っているか）。
    static func canUse(_ feature: PlusFeature, itemID: String) -> Bool {
        let used = usedIDs(for: feature)
        return used.contains(itemID) || used.count < feature.freeLimit
    }

    static func recordUse(_ feature: PlusFeature, itemID: String) {
        var used = usedIDs(for: feature)
        guard used.insert(itemID).inserted,
              let data = try? JSONEncoder().encode(used.sorted()),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        KeychainStore.shared.set(raw, forKey: key(for: feature))
    }
}

/// Komap Plus（自動更新サブスクリプション）の購入・復元と、今 Plus かどうかの状態。
///
/// 購入状態は StoreKit 2 の`Transaction.currentEntitlements`（端末で検証済みのもの）から判断する。
/// サインイン中は、Web版でも Plus の特典（Kindle本の全文）を使えるよう、取引IDを
/// Cloud Function（`syncPlusEntitlement`）へ送る。サーバー側は Apple に問い合わせて確かめる。
@MainActor
final class PlusStore: ObservableObject {
    static let monthlyProductID = "com.komap.Komap.plus.monthly"
    static let yearlyProductID = "com.komap.Komap.plus.yearly"
    static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]

    /// Web版で Kindle本を開くリンク（`?book=1`でKindle原稿のモーダルが開く）。
    static let kindleWebURL = URL(string: "https://komap.ktrips.net/?book=1")!

    @Published private(set) var products: [Product] = []
    /// App Store で Plus を購入していて、期限内かどうか。
    @Published private(set) var hasPurchase: Bool = UserDefaults.standard.bool(forKey: PlusStore.cachedIsPlusKey)
    /// 管理者（`AuthService.adminEmail`）でサインイン中なら、購入しなくても Plus として扱う。
    @Published private(set) var isAdminGrant = false
    @Published private(set) var currentProductID: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var willAutoRenew = true
    @Published private(set) var isEligibleForFreeTrial = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    /// 起動直後に一瞬「無料版」の表示になるのを避けるため、前回の判定結果を覚えておく。
    private static let cachedIsPlusKey = "plusStore.cachedIsPlus"

    private var updatesTask: Task<Void, Never>?
    private var originalTransactionID: UInt64?
    /// サインイン中のアカウント（`RootView`から`setSignedInUser`で渡す）。
    private var signedInUserID: String?

    /// 今 Plus の機能を使えるか（購入済み、または管理者）。
    var isPlus: Bool { hasPurchase || isAdminGrant }

    /// 年額プラン（比較ページでおすすめとして先頭に出す）。
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyProductID } }
    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductID } }

    /// 起動時に一度呼ぶ。商品情報の読み込み・購入状態の確認・購入の更新の監視を始める。
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price > $1.price }
            if let subscription = yearlyProduct?.subscription ?? monthlyProduct?.subscription {
                isEligibleForFreeTrial = await subscription.isEligibleForIntroOffer
            }
        } catch {
            errorMessage = "プランの情報を読み込めませんでした。通信状況を確認して、もう一度お試しください。"
        }
    }

    /// 端末で検証済みの購入から、今 Plus かどうかを判断し直す。
    func refreshEntitlements() async {
        var active: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  (transaction.expirationDate ?? .distantFuture) > Date()
            else { continue }
            if (transaction.expirationDate ?? .distantFuture) > (active?.expirationDate ?? .distantPast) {
                active = transaction
            }
        }

        hasPurchase = active != nil
        currentProductID = active?.productID
        expirationDate = active?.expirationDate
        originalTransactionID = active?.originalID
        UserDefaults.standard.set(hasPurchase, forKey: Self.cachedIsPlusKey)

        if let product = products.first(where: { $0.id == active?.productID }),
           let statuses = try? await product.subscription?.status,
           let status = statuses.first(where: { status in
               if case .verified(let transaction) = status.transaction { return transaction.originalID == active?.originalID }
               return false
           }),
           case .verified(let renewalInfo) = status.renewalInfo {
            willAutoRenew = renewalInfo.willAutoRenew
        }

        // 購入状態が変わったら、サインイン中のアカウントにも記録し直す。
        await syncToServer()
    }

    /// サインイン・サインアウトのたびに呼ぶ。サインインしたら、そのアカウントに Plus の購入を記録する。
    /// 管理者のアカウントなら、購入しなくても Plus になる（Web版では Cloud Function 側で同じ判定をする）。
    func setSignedInUser(_ userID: String?, email: String?) async {
        signedInUserID = userID
        isAdminGrant = userID != nil && email?.lowercased() == AuthService.adminEmail
        await syncToServer()
    }

    /// 購入する。サインイン中なら、その購入がこのアカウントのものだとわかる印（appAccountToken）を付ける。
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        var options: Set<Product.PurchaseOption> = []
        if let signedInUserID {
            options.insert(.appAccountToken(Self.appAccountToken(for: signedInUserID)))
        }
        do {
            switch try await product.purchase(options: options) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
            case .success(.unverified):
                errorMessage = "購入を確認できませんでした。時間をおいて「購入を復元」をお試しください。"
            case .pending:
                errorMessage = "購入の承認を待っています。承認されると自動で Plus になります。"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入できませんでした: \(error.localizedDescription)"
        }
    }

    /// 「購入を復元」。App Store と購入履歴を同期してから、購入状態を確かめ直す。
    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !hasPurchase {
                errorMessage = "このApple IDでは、有効な Komap Plus の購入が見つかりませんでした。"
            }
        } catch {
            errorMessage = "購入を復元できませんでした: \(error.localizedDescription)"
        }
    }

    /// サインイン中のアカウントに、Plus の購入を記録する（Web版の特典に使う）。
    /// 失敗してもアプリ内の Plus 機能には影響しないため、エラーは表示しない。
    private func syncToServer() async {
        guard signedInUserID != nil, let originalTransactionID, FirebaseApp.app() != nil else { return }
        do {
            _ = try await Functions.functions(region: "asia-northeast1")
                .httpsCallable("syncPlusEntitlement")
                .call(["originalTransactionId": String(originalTransactionID)])
        } catch {
            print("Komap Plus の購入をアカウントに記録できませんでした: \(error.localizedDescription)")
        }
    }

    /// 回数制限のある機能を、この場所・旅で使えるか（Plus なら常に使える）。
    func canUse(_ feature: PlusFeature, itemID: String) -> Bool {
        isPlus || PlusFreeUsage.canUse(feature, itemID: itemID)
    }

    /// 無料枠を1回分使ったことを記録する（Plus の間は記録しない）。
    func recordFreeUse(_ feature: PlusFeature, itemID: String) {
        guard !isPlus else { return }
        PlusFreeUsage.recordUse(feature, itemID: itemID)
        objectWillChange.send()
    }

    /// Firebase の uid から作る、購入とアカウントを結び付けるためのUUID。
    /// Cloud Function（`functions/src/plus.ts`の`appAccountToken`）と同じ計算（SHA-256の先頭16バイト）。
    static func appAccountToken(for userID: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(userID.utf8)).prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
