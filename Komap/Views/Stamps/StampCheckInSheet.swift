import PhotosUI
import SwiftUI

/// 御朱印を獲得した直後、または御朱印帳から後で開いた時に、
/// その史跡の写真を追加・変更できるシート。
struct StampCheckInSheet: View {
    let site: HistoricSite
    @Bindable var stamp: CollectedStamp

    @Environment(\.dismiss) private var dismiss
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color(red: 0.72, green: 0.53, blue: 0.15))
                        Text(site.name)
                            .font(.title2.bold())
                        Text(site.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let photo = stamp.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        if isLoadingPhoto {
                            ProgressView()
                        } else {
                            Label(stamp.photo == nil ? "写真を追加" : "写真を変更", systemImage: "camera")
                        }
                    }
                    .disabled(isLoadingPhoto)

                    if stamp.photo != nil {
                        Button("写真を削除", role: .destructive) {
                            stamp.updatePhoto(nil)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("チェックイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                loadPickedPhoto(newItem)
            }
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true
        Task {
            defer { isLoadingPhoto = false }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else { return }
            stamp.updatePhoto(uiImage)
        }
    }
}
