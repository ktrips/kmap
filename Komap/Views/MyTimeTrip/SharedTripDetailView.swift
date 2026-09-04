import CoreLocation
import SwiftUI

/// 「みんなの時空旅」から選んだ、他ユーザーが公開している時空旅1件の詳細。
/// 使っていた古地図・歩いたルート・御朱印/投稿写真に加え、いいね・コメントもできる。
struct SharedTripDetailView: View {
    let trip: RemoteSharedTrip

    @EnvironmentObject private var authService: AuthService

    private var overlayMap: HistoricalOverlayMap? {
        OldMapCatalog.resolve(id: trip.overlayMapID)
    }

    private var coordinates: [CLLocationCoordinate2D] {
        zip(trip.latitudes, trip.longitudes).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WalkRouteMapView(
                    overlayMap: overlayMap,
                    overlayOpacity: 0.6,
                    path: coordinates,
                    checkpoints: [],
                    collectedSiteIDs: []
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                header

                if !trip.stampPhotos.isEmpty {
                    photoSection(title: "御朱印", photos: trip.stampPhotos)
                }

                if !trip.postPhotos.isEmpty {
                    photoSection(title: "投稿写真", photos: trip.postPhotos)
                }

                TripEngagementView(
                    tripID: trip.id,
                    currentUserID: authService.userID,
                    currentUserDisplayName: authService.displayName
                )
            }
            .padding()
        }
        .navigationTitle("時間旅の記録")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = trip.title, !title.isEmpty {
                Text(title)
                    .font(.title3.bold())
                Text(trip.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(trip.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.title3.bold())
            }

            Text(overlayMap?.title ?? "古地図なし")
                .font(.subheadline.bold())
                .foregroundStyle(.brown)

            if let ownerName = trip.ownerDisplayName, !ownerName.isEmpty {
                Label("投稿者：\(ownerName)", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(distanceText, systemImage: "figure.walk")
                if let stepCount = trip.stepCount {
                    Label("\(stepCount)歩", systemImage: "shoeprints.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func photoSection(title: String, photos: [RemoteSharedPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(photos, id: \.url) { photo in
                    VStack(spacing: 4) {
                        AsyncImage(url: URL(string: photo.url)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color(.secondarySystemBackground)
                        }
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        if !photo.label.isEmpty {
                            Text(photo.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var distanceText: String {
        let meters = trip.totalDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
