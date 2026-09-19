import PhotosUI
import SwiftUI

/// チェックインと投稿写真の詳細で共通の、写真まわりの操作ボタン行
/// （写真を変更／連携プリント／非公開／削除）。両画面で並びと見た目をそろえるために共有する。
struct PhotoDetailActionRow: View {
    /// 写真がまだ無い時は「写真を追加」になる。
    var hasPhoto: Bool
    var isBusy: Bool = false
    var showsPrint: Bool
    var isPrinting: Bool
    var isHidden: Bool
    var isUpdatingVisibility: Bool
    /// 「非公開」「削除」を出すか（写真がある時だけ意味がある）。
    var showsRemoveActions: Bool
    var onChange: () -> Void
    var onPrint: () -> Void
    var onToggleHidden: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onChange) {
                Label(hasPhoto ? "写真を変更" : "写真を追加", systemImage: "camera.fill")
            }
            .disabled(isBusy)

            if showsPrint {
                Button(action: onPrint) {
                    if isPrinting {
                        ProgressView()
                    } else {
                        Label("連携プリント", systemImage: "printer.fill")
                    }
                }
                .disabled(isPrinting)
            }

            if showsRemoveActions {
                Button(action: onToggleHidden) {
                    if isUpdatingVisibility {
                        ProgressView()
                    } else {
                        Label(
                            isHidden ? "非公開中" : "非公開",
                            systemImage: isHidden ? "eye.slash.fill" : "eye.slash"
                        )
                    }
                }
                .disabled(isUpdatingVisibility)

                Button(role: .destructive, action: onDelete) {
                    Label("削除", systemImage: "trash")
                }
            }
        }
        // 4つ並んでも横一線に収まるよう、折り返さず必要なら少し縮める。
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// 「写真を変更」で、まずカメラを開き、その左下のボタンからライブラリの写真にも
/// 切り替えられるようにする（チェックイン・投稿写真の詳細で共通）。
/// 選んだ・撮った写真は`onPick`に渡す。
private struct PhotoChangePickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    var onPick: (UIImage) -> Void

    @State private var isShowingLibrary = false
    /// `fullScreenCover`の閉じるアニメーションとピッカー表示の競合を避けるため、
    /// カメラが閉じ終わってからライブラリを開くための一時フラグ。
    @State private var shouldShowLibraryAfterCameraDismiss = false
    @State private var pickerItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isShowingLibrary, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                pickerItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data)
                    else { return }
                    onPick(image)
                }
            }
            .fullScreenCover(isPresented: $isPresented, onDismiss: {
                guard shouldShowLibraryAfterCameraDismiss else { return }
                shouldShowLibraryAfterCameraDismiss = false
                isShowingLibrary = true
            }) {
                ZStack(alignment: .bottomLeading) {
                    CameraCaptureView(
                        onCapture: { image in
                            isPresented = false
                            onPick(image)
                        },
                        onCancel: { isPresented = false }
                    )
                    .ignoresSafeArea()

                    // 標準カメラアプリのライブラリショートカットと同じ左下の位置。
                    Button {
                        shouldShowLibraryAfterCameraDismiss = true
                        isPresented = false
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 40)
                }
            }
    }
}

extension View {
    func photoChangePicker(isPresented: Binding<Bool>, onPick: @escaping (UIImage) -> Void) -> some View {
        modifier(PhotoChangePickerModifier(isPresented: isPresented, onPick: onPick))
    }
}
