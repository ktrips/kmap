import SwiftUI

/// 「連携機能」（同じWi-Fi上のカメラ端末・プリンターとの連携）をまとめた設定画面。
/// 「設定」画面の「連携機能」から開く。
struct LinkedDevicesSettingsView: View {
    @State private var cameraLinkHost: String = AppSettings.cameraLinkHost ?? ""
    @State private var cameraLinkSavedMessage: String?

    @State private var printerLinkHost: String = AppSettings.printerLinkHost ?? ""
    @State private var printerSyncStamps: Bool = AppSettings.printerSyncStamps
    @State private var printerSyncPhotoPosts: Bool = AppSettings.printerSyncPhotoPosts
    @State private var printerImageSize: PrinterImageSize = AppSettings.printerImageSize
    @State private var printerImageQuality: PrinterImageQuality = AppSettings.printerImageQuality
    @State private var printerIsGrayscale: Bool = AppSettings.printerIsGrayscale
    @State private var printerImageFormat: PrinterImageFormat = AppSettings.printerImageFormat
    @State private var printerTransferMode: PrinterTransferMode = AppSettings.printerTransferMode
    @State private var printerLinkSavedMessage: String?

    var body: some View {
        Form {
            cameraLinkSection
            printerLinkSection
        }
        .navigationTitle("連携機能")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cameraLinkSection: some View {
        Section {
            TextField("例: m5web.local", text: $cameraLinkHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("保存する") {
                AppSettings.cameraLinkHost = cameraLinkHost
                cameraLinkSavedMessage = "保存しました"
            }
            if let cameraLinkSavedMessage {
                Text(cameraLinkSavedMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("カメラ連携")
        } footer: {
            Text("同じWi-Fi上で写真を撮れるURL（例: M5Stackなどのカメラ端末）を設定すると、御朱印・写真投稿の画面に「連携カメラで撮る」が追加されます。")
        }
    }

    private var printerLinkSection: some View {
        Section {
            TextField("例: m5web.local", text: $printerLinkHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Toggle("御朱印の写真を連携する", isOn: $printerSyncStamps)
                .onChange(of: printerSyncStamps) { _, newValue in
                    AppSettings.printerSyncStamps = newValue
                }
            Toggle("投稿写真を連携する", isOn: $printerSyncPhotoPosts)
                .onChange(of: printerSyncPhotoPosts) { _, newValue in
                    AppSettings.printerSyncPhotoPosts = newValue
                }
            Picker("転送方式", selection: $printerTransferMode) {
                ForEach(PrinterTransferMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: printerTransferMode) { _, newValue in
                AppSettings.printerTransferMode = newValue
            }
            Picker("写真の大きさ", selection: $printerImageSize) {
                ForEach(PrinterImageSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: printerImageSize) { _, newValue in
                AppSettings.printerImageSize = newValue
            }
            Picker("画質", selection: $printerImageQuality) {
                ForEach(PrinterImageQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: printerImageQuality) { _, newValue in
                AppSettings.printerImageQuality = newValue
            }
            Picker("ファイル形式", selection: $printerImageFormat) {
                ForEach(PrinterImageFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: printerImageFormat) { _, newValue in
                AppSettings.printerImageFormat = newValue
            }
            Toggle("白黒で転送する", isOn: $printerIsGrayscale)
                .onChange(of: printerIsGrayscale) { _, newValue in
                    AppSettings.printerIsGrayscale = newValue
                }
            Button("保存する") {
                AppSettings.printerLinkHost = printerLinkHost
                printerLinkSavedMessage = "保存しました"
            }
            if let printerLinkSavedMessage {
                Text(printerLinkSavedMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("連携プリンター")
        } footer: {
            Text("同じWi-Fi上で写真を受け取れるプリンターのホスト名／IP（パスは不要）を設定すると、チェックをつけた種類の写真が撮影・追加のたびに自動で転送されるほか、御朱印・投稿写真の詳細画面に表示される「連携プリント」ボタンから、後で見返した写真をその場で転送することもできます。大きさ・画質・ファイル形式（JPEG／PNG）・白黒の設定は転送する写真にだけ適用され、端末やクラウドに保存される写真は変わりません。\n「転送方式」が「写真データを直接送信」の場合はPOST <ホスト>/api/print/photoへmultipart/form-data（フィールド名photo）で画像を送ります。「写真のURLを渡す」の場合は、画像を一度アップロードしてGET <ホスト>/api/print/photo/url?url=<画像のURL>を呼びます（サインインが必要です）。")
        }
    }
}

#Preview {
    NavigationStack {
        LinkedDevicesSettingsView()
    }
}
