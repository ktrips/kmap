import SwiftUI

/// 古地図の説明の共通の中身。「地図上部の古地図名」と「古地図を選択の詳細」の両方で
/// 同じ形式で表示する: 古地図の画像とその上のチェックポイント（番号つきのピン）、
/// 時代・紹介文、番号に対応したチェックポイントの説明。
struct OverlayInfoContent: View {
    let overlay: HistoricalOverlayMap
    let checkpoints: [HistoricSite]
    /// 詳細画面でだけ添える補足（分類・範囲）。
    var category: String?
    var showsRange = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            mapWithCheckpoints

            VStack(alignment: .leading, spacing: 6) {
                if let category {
                    Label(category, systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label(overlay.era, systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.bold())
                    .foregroundStyle(.brown)
                Text(overlay.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if showsRange {
                    Text(String(
                        format: "範囲: 南西 %.4f, %.4f ／ 北東 %.4f, %.4f",
                        overlay.southWest.latitude, overlay.southWest.longitude,
                        overlay.northEast.latitude, overlay.northEast.longitude
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if !checkpoints.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("チェックポイント（\(checkpoints.count)件）")
                        .font(.headline)
                    ForEach(Array(checkpoints.enumerated()), id: \.element.id) { index, site in
                        HStack(alignment: .top, spacing: 10) {
                            PinBadge(number: index + 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(site.name)
                                    .font(.subheadline.bold())
                                if !site.summary.isEmpty {
                                    Text(site.summary)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("この古地図にはチェックポイントがありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 古地図の画像と、その上に重ねた番号つきのチェックポイントのピン。
    @ViewBuilder
    private var mapWithCheckpoints: some View {
        if let image = overlay.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                // 角を丸めるのは画像だけにし、縁にあるピンが切れないよう、ピンはその上に重ねる。
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    GeometryReader { geometry in
                        ForEach(Array(checkpoints.enumerated()), id: \.element.id) { index, site in
                            if let fraction = overlay.imageFraction(of: site.coordinate),
                               (0...1).contains(fraction.u), (0...1).contains(fraction.v) {
                                PinBadge(number: index + 1)
                                    .position(
                                        x: geometry.size.width * fraction.u,
                                        y: geometry.size.height * fraction.v
                                    )
                            }
                        }
                    }
                }
        }
    }
}

/// チェックポイントの番号を示す丸いバッジ（地図上のピンと、下の一覧で共通）。
private struct PinBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color(uiColor: .shuiro), in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}
