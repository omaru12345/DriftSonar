import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import DriftSonarCore

/// TASK-130 (EP-025): DM 相手との「安全番号を確認」画面。
///
/// 双方の長期公開鍵から順序非依存で導かれる安全番号（Signal の Safety Number 相当）を
/// 数列と QR コードで表示する。相手の端末と対面で数列・QR を突き合わせ、一致すれば
/// 途中で公開鍵がすり替えられていない（中間者攻撃が無い）ことを確認できる。
struct SafetyNumberView: View {
    let safetyNumber: SafetyNumber
    /// 相手の表示名（ニックネームまたはフィンガープリント）。説明文に添える。
    let peerName: String
    /// TASK-131: この相手が既に検証済みか（呼び出し時点の状態）。
    var isVerified: Bool = false
    /// TASK-131: スキャンした QR ペイロードを突合・保存する。結果を受けて表示を更新する。
    /// `nil` のときはスキャン導線を出さない（プレビュー等）。
    var onScan: ((String) -> ContactVerificationResult)?

    @Environment(\.dismiss) private var dismiss

    /// TASK-131: カメラスキャナの提示状態。
    @State private var showScanner = false
    /// TASK-131: スキャンで読み取ったペイロード。スキャナが閉じ切ってから突合＋アラート提示する
    /// （`fullScreenCover` の閉じアニメーション中に親の `.alert` を出すと無視される SwiftUI の競合を回避）。
    @State private var pendingScan: String?
    /// TASK-131: この画面でスキャン突合に成功したか（提示中の即時反映用）。
    @State private var justVerified = false
    /// TASK-131: 突合結果のフィードバック（一致/不一致/解釈不能）を伝えるアラート。
    @State private var scanFeedback: ScanFeedback?

    /// 検証済み表示は「呼び出し時点で検証済み」または「この画面で検証成功」のいずれか。
    private var showsVerified: Bool { isVerified || justVerified }

    /// 安全番号を対面突合用に QR へ載せるときのペイロード。スキームは Core の
    /// `SafetyNumber.qrScheme` に一元化し、TASK-131 のスキャン照合側と食い違わないようにする。
    private var qrPayload: String { safetyNumber.qrPayload }

    /// 60 桁を 5 桁 × 12 ブロックへ区切った読み上げ単位。3 列 × 4 行のグリッドで見せる。
    private var blocks: [String] {
        let digits = safetyNumber.digits
        return stride(from: 0, to: digits.count, by: 5).map { offset in
            let start = digits.index(digits.startIndex, offsetBy: offset)
            let end = digits.index(start, offsetBy: min(5, digits.count - offset))
            return String(digits[start..<end])
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DSLayout.Spacing.sm), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSLayout.Spacing.xl) {
                    intro
                    if showsVerified { verifiedBanner }
                    qrCard
                    digitBlocks
                    if onScan != nil { scanButton }
                    reassurance
                }
                .padding()
            }
            .background(Color.dsBackground)
            .navigationTitle("安全番号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        // TASK-131: 相手の QR を読み取って自端末計算値と突合する。突合とアラート提示は
        // スキャナが閉じ切った onDismiss で行い、presentation の競合を避ける。
        .fullScreenCover(isPresented: $showScanner, onDismiss: {
            guard let payload = pendingScan else { return }
            pendingScan = nil
            handleScanned(payload)
        }) {
            QRScannerView(onFound: { pendingScan = $0 })
        }
        .alert(item: $scanFeedback) { feedback in
            Alert(title: Text(feedback.title), message: Text(feedback.message),
                  dismissButton: .default(Text("OK")))
        }
    }

    /// スキャン結果を突合し、UI へ反映する。
    private func handleScanned(_ payload: String) {
        guard let onScan else { return }
        switch onScan(payload) {
        case .verified:
            justVerified = true
            scanFeedback = ScanFeedback(
                title: "確認できました",
                message: "\(peerName) の安全番号が一致しました。この会話は途中で盗み見られていません。"
            )
        case .mismatch:
            scanFeedback = ScanFeedback(
                title: "番号が一致しません",
                message: "相手の鍵がすり替えられている可能性があります。同じ相手であることを対面で確かめてください。"
            )
        case .invalidPayload:
            scanFeedback = ScanFeedback(
                title: "読み取れませんでした",
                message: "DriftSonar の安全番号 QR ではありません。相手の「安全番号」画面を読み取ってください。"
            )
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(spacing: DSLayout.Spacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.seaGlass)
                .accessibilityHidden(true)
            Text("\(peerName) との安全番号")
                .font(.dsTitle)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.center)
            Text("対面で相手の画面と見比べ、数列（または QR）が一致すれば、この会話は途中で盗み見られていません。")
                .font(.dsBody)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var qrCard: some View {
        if let image = Self.qrImage(from: qrPayload) {
            image
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 240)
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.Radius.lg))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .accessibilityLabel("安全番号の QR コード")
        } else {
            ContentUnavailableView("QR コードを生成できません", systemImage: "qrcode.viewfinder")
        }
    }

    private var digitBlocks: some View {
        VStack(spacing: DSLayout.Spacing.sm) {
            LazyVGrid(columns: columns, spacing: DSLayout.Spacing.sm) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    Text(block)
                        .font(.dsMono(.body))
                        .foregroundStyle(Color.dsTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSLayout.Spacing.sm)
                        .background(
                            Color.dsSurface,
                            in: RoundedRectangle(cornerRadius: DSLayout.Radius.sm)
                        )
                }
            }
            // 数列は読み上げ突合が本質なので、VoiceOver では区切りごとに一続きで読ませる。
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("安全番号 \(safetyNumber.formatted)")
        }
    }

    // TASK-131: 検証済みバンド。突合成功後・既検証時に安心材料として上部へ出す。
    private var verifiedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text("この相手は確認済みです")
        }
        .font(.dsBody)
        .foregroundStyle(Color.seaGlass)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSLayout.Spacing.sm)
        .padding(.horizontal, DSLayout.Spacing.md)
        .background(Color.seaGlass.opacity(0.16), in: RoundedRectangle(cornerRadius: DSLayout.Radius.md))
    }

    // TASK-131: 相手の QR を読み取って自動突合する導線。目視突合より確実。
    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            Label(showsVerified ? "もう一度スキャンして確認" : "相手の QR をスキャンして確認",
                  systemImage: "qrcode.viewfinder")
                .font(.dsBody)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSLayout.Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.deepTide)
    }

    private var reassurance: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("番号が一致しない場合は、相手の鍵がすり替えられている可能性があります。")
        }
        .font(.dsCaption)
        .foregroundStyle(Color.dsTextSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSLayout.Spacing.sm)
        .padding(.horizontal, DSLayout.Spacing.md)
        .background(Color.seaGlass.opacity(0.14), in: RoundedRectangle(cornerRadius: DSLayout.Radius.md))
    }

    // MARK: - QR generation

    /// 与えられた文字列を QR コード画像へ変換する（既存 PublicKeyQRView と同じ CoreImage 手順）。
    private static func qrImage(from string: String) -> Image? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

// MARK: - ScanFeedback

/// TASK-131: スキャン突合結果のアラート内容。`.alert(item:)` 用。
private struct ScanFeedback: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
