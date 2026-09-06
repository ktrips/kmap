import SwiftUI

/// 「連携機能」（同じWi-Fi上のカメラ端末・プリンターとの連携）をまとめた設定画面。
/// 「設定」画面の「連携機能」から開く。
struct LinkedDevicesSettingsView: View {
    @State private var cameraLinkHost: String = AppSettings.cameraLinkHost ?? ""
    @State private var cameraLinkSavedMessage: String?

    @State private var printerLinkHost: String = AppSettings.printerLinkHost ?? ""
    @State private var printerLinkSavedMessage: String?

    // 以下はトグル・Pickerを操作した瞬間に`AppSettings`（UserDefaults）へ直接
    // 読み書きするバインディングにしている（ローカルの`@State`を別途持って
    // `onChange`で書き戻す形にすると、この画面が作り直された時にローカル側の
    // 値がずれて「保存したのに元に戻る」ように見えることがあったため）。
    private var printerSyncStamps: Binding<Bool> {
        Binding(get: { AppSettings.printerSyncStamps }, set: { AppSettings.printerSyncStamps = $0 })
    }
    private var printerSyncPhotoPosts: Binding<Bool> {
        Binding(get: { AppSettings.printerSyncPhotoPosts }, set: { AppSettings.printerSyncPhotoPosts = $0 })
    }
    private var printerImageSize: Binding<PrinterImageSize> {
        Binding(get: { AppSettings.printerImageSize }, set: { AppSettings.printerImageSize = $0 })
    }
    private var printerImageQuality: Binding<PrinterImageQuality> {
        Binding(get: { AppSettings.printerImageQuality }, set: { AppSettings.printerImageQuality = $0 })
    }
    private var printerIsGrayscale: Binding<Bool> {
        Binding(get: { AppSettings.printerIsGrayscale }, set: { AppSettings.printerIsGrayscale = $0 })
    }
    private var printerImageFormat: Binding<PrinterImageFormat> {
        Binding(get: { AppSettings.printerImageFormat }, set: { AppSettings.printerImageFormat = $0 })
    }
    private var printerTransferMode: Binding<PrinterTransferMode> {
        Binding(get: { AppSettings.printerTransferMode }, set: { AppSettings.printerTransferMode = $0 })
    }

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
            Toggle("御朱印の写真を連携する", isOn: printerSyncStamps)
            Toggle("投稿写真を連携する", isOn: printerSyncPhotoPosts)
            Picker("転送方式", selection: printerTransferMode) {
                ForEach(PrinterTransferMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            Picker("写真の大きさ", selection: printerImageSize) {
                ForEach(PrinterImageSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }
            .pickerStyle(.menu)
            Picker("画質", selection: printerImageQuality) {
                ForEach(PrinterImageQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            .pickerStyle(.menu)
            Picker("ファイル形式", selection: printerImageFormat) {
                ForEach(PrinterImageFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.menu)
            Toggle("白黒で転送する", isOn: printerIsGrayscale)
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
            Text("プリンター連携")
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
