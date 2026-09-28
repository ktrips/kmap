import StoreKit
import SwiftUI

/// 無料版と Komap Plus の比較ページ。「設定」→「Komap Plus」から開くほか、
/// 写真の追加・場所の詳細・旅の動画など Plus の機能を使おうとした時にも開く
/// （その場合は`reason`で、開いた理由を冒頭に表示する）。
struct PlusComparisonView: View {
    /// どの機能から開かれたか。「設定」から開いた時は`nil`。
    var reason: PlusFeature?
    /// シートとして開いた時は、左上に「閉じる」を出す。
    var showsCloseButton = true

    @EnvironmentObject private var plusStore: PlusStore
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedProductID = PlusStore.yearlyProductID
    @State private var isShowingManageSubscriptions = false

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let free: String
        let plus: String
    }

    private var rows: [Row] {
        let detailLeft = PlusFreeUsage.remaining(for: .placeDetail)
        let videoLeft = PlusFreeUsage.remaining(for: .tripVideo)
        return [
            Row(title: "古地図の上を歩いて記録", free: "✓", plus: "✓"),
            Row(title: "御朱印・紋章を集める", free: "✓", plus: "✓"),
            Row(title: "歩数・距離・ポイント", free: "✓", plus: "✓"),
            Row(title: "写真の追加（投稿・御朱印）", free: "—", plus: "✓"),
            Row(title: "場所の詳細（AIの解説）", free: "3か所まで\n（残り\(detailLeft)）", plus: "無制限"),
            Row(title: "旅の動画の作成", free: "1本まで\n（残り\(videoLeft)）", plus: "無制限"),
            Row(title: "AIの旅日記", free: "—", plus: "✓"),
            Row(title: "Kindle本「Komapの作り方」", free: "冒頭約10ページ", plus: "全文（Web）"),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    comparisonTable
                    if plusStore.isPlus {
                        memberSection
                    } else {
                        planSection
                    }
                    footer
                }
                .padding()
            }
            .navigationTitle("Komap Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
            .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
            .task {
                if plusStore.products.isEmpty { await plusStore.loadProducts() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(plusStore.isPlus ? "Komap Plus 会員です" : "Komap Plus", systemImage: "seal.fill")
                .font(.title2.bold())
                .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
            if let reason, !plusStore.isPlus {
                Text(reason.paywallMessage)
                    .font(.subheadline)
            } else if !plusStore.isPlus {
                Text("歩くことと御朱印集めは無料のまま。Plus なら、写真・場所の詳細・旅の動画・AIの旅日記で、時空旅をもっと深く残せます。")
                    .font(.subheadline)
            }
        }
    }

    private var comparisonTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                Text("無料").font(.caption.bold()).foregroundStyle(.secondary).gridColumnAlignment(.center)
                Text("Plus").font(.caption.bold()).foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15)).gridColumnAlignment(.center)
            }
            Divider()
            ForEach(rows) { row in
                GridRow {
                    Text(row.title).font(.subheadline)
                    Text(row.free)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(row.plus)
                        .font(.caption.bold())
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            planButton(
                productID: PlusStore.yearlyProductID,
                title: "年額プラン",
                price: plusStore.yearlyProduct?.displayPrice ?? "¥3,800",
                note: "月あたり約317円・月額より約3割お得",
                isRecommended: true
            )
            planButton(
                productID: PlusStore.monthlyProductID,
                title: "月額プラン",
                price: plusStore.monthlyProduct?.displayPrice ?? "¥480",
                note: "いつでも解約できます",
                isRecommended: false
            )

            Button {
                Task { await plusStore.purchase(productID: selectedProductID) }
            } label: {
                Group {
                    if plusStore.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(plusStore.isEligibleForFreeTrial ? "7日間無料で試す" : "Plus に登録する")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.55, green: 0.36, blue: 0.16))
            .disabled(plusStore.isPurchasing)

            if plusStore.isEligibleForFreeTrial {
                Text("無料期間が終わると、選んだプランで自動的に課金されます。無料期間中に解約すれば料金はかかりません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if authService.userID == nil {
                Label("Kindle本の全文をWebで読むには、登録の前にアカウントにサインインしておいてください。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = plusStore.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("購入を復元") {
                Task { await plusStore.restore() }
            }
            .font(.subheadline)
            .disabled(plusStore.isPurchasing)
        }
    }

    private func planButton(productID: String, title: String, price: String, note: String, isRecommended: Bool) -> some View {
        let isSelected = selectedProductID == productID
        return Button {
            selectedProductID = productID
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color(red: 0.55, green: 0.36, blue: 0.16) : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.subheadline.bold())
                        if isRecommended {
                            Text("おすすめ")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(price).font(.headline)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.55, green: 0.36, blue: 0.16) : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if plusStore.isAdminGrant && !plusStore.hasPurchase {
                Label("管理者のアカウントのため、購入しなくても Plus の機能を使えます。", systemImage: "person.badge.key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let expirationDate = plusStore.expirationDate {
                Text(plusStore.willAutoRenew
                     ? "次回の更新日: \(expirationDate.formatted(date: .long, time: .omitted))"
                     : "\(expirationDate.formatted(date: .long, time: .omitted))まで利用できます（自動更新はオフです）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                openURL(PlusStore.kindleWebURL)
            } label: {
                Label("Kindle本の全文をWebで読む", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.55, green: 0.36, blue: 0.16))

            if authService.userID == nil {
                Label("Webで全文を読むには、「設定」でアカウントにサインインしてください。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if plusStore.hasPurchase {
                Button("サブスクリプションを管理") {
                    isShowingManageSubscriptions = true
                }
                .font(.subheadline)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("お支払いはApple IDに請求されます。サブスクリプションは、現在の期間が終わる24時間以上前に解約しない限り、自動的に更新されます。解約はiPhoneの「設定」→ Apple ID →「サブスクリプション」から行えます。これまでに残した写真・動画は、解約後も見ることができます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("プライバシーポリシー", destination: URL(string: "https://komap.ktrips.net/privacy.html")!)
            }
            .font(.caption)
        }
    }
}
