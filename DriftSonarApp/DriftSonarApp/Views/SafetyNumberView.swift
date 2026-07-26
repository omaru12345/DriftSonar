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

    @Environment(\.dismiss) private var dismiss

    /// 安全番号を対面突合用に QR へ載せるときのスキーム。既存の `driftsonar://pk/` と揃える。
    /// TASK-131 のスキャン照合はこのペイロードを解釈して相手側計算値と突き合わせる。
    private var qrPayload: String { "driftsonar://sn/\(safetyNumber.digits)" }

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
                    qrCard
                    digitBlocks
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
