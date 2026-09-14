import SwiftUI

/// 「マイ時空旅」の「みんなの時空旅」タブ。自分の記録も含め、公開済みの時空旅
/// （`sharedTrips`）を開始日時が新しい順に、サムネイル付きの行で一覧表示する。
/// Web版の「みんなの時空旅」と同じデータを見る、閲覧専用の画面。
struct EveryoneTimeTripView: View {
    @State private var trips: [RemoteSharedTrip] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTrip: RemoteSharedTrip?

    private let syncService = SyncService()

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("みんなの時空旅を読み込んでいます…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                    Button("もう一度試す") {
                        Task { await load() }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if trips.isEmpty {
                Text("まだ公開されている時空旅がありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(trips) { trip in
                            SharedTripRow(trip: trip)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTrip = trip
                                }
                            Divider()
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await load()
        }
        .sheet(item: $selectedTrip) { trip in
            SharedTripDetailSheet(trip: trip)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            trips = try await syncService.fetchAllSharedTrips()
        } catch {
            errorMessage = "みんなの時空旅を取得できませんでした: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

/// 一覧1件分の行。左にサムネイル、右に旅の名前・投稿者・日時・距離を並べる
/// （マイ時空旅内の他の一覧行と見た目のレベル感を揃えている）。
private struct SharedTripRow: View {
    let trip: RemoteSharedTrip

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter
    }()

    private var distanceText: String {
        let meters = trip.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let url = trip.thumbnailURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.secondary.opacity(0.15)
                        }
                    }
                } else {
                    Image(systemName: "map.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title ?? trip.overlayMap?.title ?? "名称未設定の時空旅")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let ownerDisplayName = trip.ownerDisplayName, !ownerDisplayName.isEmpty {
                        Label(ownerDisplayName, systemImage: "person.fill")
                    }
                    Text(Self.dateFormatter.string(from: trip.startedAt))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                Text("\(distanceText) ・ 御朱印\(trip.stampPhotos.count)件 ・ 写真\(trip.postPhotos.count)件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

/// 一覧の行をタップした時に開く、公開済み時空旅の閲覧専用の詳細。
private struct SharedTripDetailSheet: View {
    let trip: RemoteSharedTrip
    @Environment(\.dismiss) private var dismiss
    @State private var enlargedPhoto: RemoteSharedPhoto?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        return formatter
    }()

    private var journalBodyText: AttributedString {
        (try? AttributedString(
            markdown: trip.travelJournalMarkdown ?? "",
            options: .init(interpretedSyntax: .full)
        )) ?? AttributedString(trip.travelJournalMarkdown ?? "")
    }

    private var distanceText: String {
        let meters = trip.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title ?? trip.overlayMap?.title ?? "名称未設定の時空旅")
                            .font(.title3.bold())
                        HStack(spacing: 12) {
                            if let ownerDisplayName = trip.ownerDisplayName, !ownerDisplayName.isEmpty {
                                Label(ownerDisplayName, systemImage: "person.fill")
                            }
                            Label(Self.dateFormatter.string(from: trip.startedAt), systemImage: "calendar")
                            Label(distanceText, systemImage: "figure.walk")
                            if let stepCount = trip.stepCount {
                                Label("\(stepCount)歩", systemImage: "shoeprints.fill")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let notes = trip.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                    }

                    if trip.travelJournalMarkdown != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(trip.travelJournalTitle ?? trip.overlayMap.map { "\($0.title)の時空旅" } ?? "時空旅")
                                .font(.headline)
                            Text(journalBodyText)
                                .font(.body)
                        }
                    }

                    if !trip.stampPhotos.isEmpty {
                        photoSection(title: "御朱印・チェックポイント", photos: trip.stampPhotos)
                    }
                    if !trip.postPhotos.isEmpty {
                        photoSection(title: "投稿した写真", photos: trip.postPhotos)
                    }
                }
                .padding()
            }
            .navigationTitle("みんなの時空旅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .sheet(item: $enlargedPhoto) { photo in
            SharedPhotoViewer(photo: photo)
        }
    }

    private func photoSection(title: String, photos: [RemoteSharedPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(photos) { photo in
                HStack(alignment: .top, spacing: 12) {
                    AsyncImage(url: URL(string: photo.url)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.secondary.opacity(0.15)
                        }
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture {
                        enlargedPhoto = photo
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if !photo.label.isEmpty {
                            Text(photo.label)
                                .font(.subheadline.bold())
                        }
                        if !photo.detail.isEmpty {
                            Text(photo.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// 写真をタップした時に、大きく表示するだけのシンプルなビューア。
private struct SharedPhotoViewer: View {
    let photo: RemoteSharedPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                AsyncImage(url: URL(string: photo.url)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    }
                }
            }
            .navigationTitle(photo.label.isEmpty ? "写真" : photo.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
