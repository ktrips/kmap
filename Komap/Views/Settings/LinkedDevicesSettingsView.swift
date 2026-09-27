import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// 「連携機能」（同じWi-Fi上のカメラ端末・プリンターとの連携）をまとめた設定画面。
/// 「設定」画面の「連携機能」から開く。
struct LinkedDevicesSettingsView: View {
    @State private var testPrintURL = "https://komap.ktrips.net/"
    @State private var isTestPrinting = false
    @State private var testPrintErrorMessage: String?
    @State private var testPrintSucceeded = false

    private let printerLinkService = PrinterLinkService()

    // ホスト名の入力欄も含め、この画面のすべての項目は`AppSettings`
    // （UserDefaults）へ直接読み書きするバインディングにしている。ローカルの
    // `@State`を別途持って明示的な「保存する」ボタンで書き戻す形だと、この画面が
    // （例えばアドバンス設定のDisclosureGroupの開閉などで）作り直された時に
    // ローカル側の値がずれて「入力したのに保存されない／元に戻る」ように
    // 見えることがあったため、常にその場で確定させる方式に統一している。
    private var cameraLinkHost: Binding<String> {
        Binding(get: { AppSettings.cameraLinkHost ?? "" }, set: { AppSettings.cameraLinkHost = $0 })
    }
    private var printerLinkHost: Binding<String> {
        Binding(get: { AppSettings.printerLinkHost ?? "" }, set: { AppSettings.printerLinkHost = $0 })
    }
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
            testPrintSection
        }
        .navigationTitle("連携機能")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cameraLinkSection: some View {
        Section {
            TextField("例: m5web.local", text: cameraLinkHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
        } header: {
            Text("カメラ連携")
        } footer: {
            Text("同じWi-Fi上のカメラ（M5Stackなど）のURLを設定すると、御朱印・写真の画面に「連携カメラで撮る」が出ます。")
        }
    }

    private var printerLinkSection: some View {
        Section {
            TextField("例: m5web.local", text: printerLinkHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
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
        } header: {
            Text("プリンター連携")
        } footer: {
            Text("同じWi-Fi上のプリンターのホスト名／IPを設定すると、撮った写真を自動で送れます。御朱印・写真の詳細の「連携プリント」からも送れます。大きさ・画質などは送る写真だけに適用されます。\n送信先: 「直接送信」はPOST <ホスト>/api/print/photo（multipart、フィールド名photo）、「URLを渡す」はGET <ホスト>/api/print/photo/url?url=<画像のURL>（サインインが必要）。")
        }
    }

    private var testPrintSection: some View {
        Section {
            TextField("URL", text: $testPrintURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button {
                Task { await runTestPrint() }
            } label: {
                if isTestPrinting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("プリント中…")
                    }
                } else {
                    Label("テストプリント", systemImage: "printer")
                }
            }
            .disabled(isTestPrinting || testPrintURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let testPrintErrorMessage {
                Text(testPrintErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if testPrintSucceeded {
                Text("連携プリンターへ送信しました。印刷結果を確認してください。")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("テストプリント")
        } footer: {
            Text("入力したURLのQRコードを、プリンターに試しに送ります。")
        }
    }

    @MainActor
    private func runTestPrint() async {
        testPrintErrorMessage = nil
        testPrintSucceeded = false

        let text = testPrintURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let qrImage = Self.qrCodeImage(from: text) else {
            testPrintErrorMessage = "QRコードを生成できませんでした。URLを確認してください。"
            return
        }

        isTestPrinting = true
        do {
            try await printerLinkService.printOnDemand(qrImage, cloudURL: nil)
            testPrintSucceeded = true
        } catch {
            testPrintErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "テストプリントに失敗しました: \(error.localizedDescription)"
        }
        isTestPrinting = false
    }

    /// 指定した文字列のQRコード画像を生成する。読み取りやすいよう、生成直後の
    /// 粗いピクセルのまま拡大せず（ぼやけるため）、`CGAffineTransform`でスケールしてから描く。
    private static func qrCodeImage(from text: String) -> UIImage? {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }

        let scale: CGFloat = 12
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    NavigationStack {
        LinkedDevicesSettingsView()
    }
}
