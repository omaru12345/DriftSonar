import AVFoundation
import SwiftUI

/// TASK-131 (EP-025): 相手の安全番号 QR を読み取るカメラスキャナ。
///
/// 検出した文字列を **一度だけ** `onFound` に渡す。突合（自端末計算値との一致判定）と
/// 検証済みの永続化は呼び出し側（`SecretMessageViewModel`）が担い、この View は撮影のみ。
/// 撮影内容は保存も送信もしない（Info.plist の `NSCameraUsageDescription` 参照）。
struct QRScannerView: View {
    /// スキャン成功時に読み取った文字列（`driftsonar://sn/<60桁>`）を渡す。
    let onFound: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    /// カメラ不可（権限拒否・シミュレータ等でデバイス無し）のときに案内へ切り替える。
    @State private var cameraUnavailable = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if cameraUnavailable {
                    unavailableMessage
                } else {
                    CameraPreview(onFound: handleFound, onUnavailable: { cameraUnavailable = true })
                        .ignoresSafeArea()
                    scanGuide
                }
            }
            .navigationTitle("QR をスキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func handleFound(_ value: String) {
        onFound(value)
        dismiss()
    }

    private var scanGuide: some View {
        VStack {
            Spacer()
            Text("相手の「安全番号」画面の QR に重ねてください")
                .font(.dsBody)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: DSLayout.Radius.md))
                .padding(.bottom, 40)
        }
    }

    private var unavailableMessage: some View {
        ContentUnavailableView {
            Label("カメラを使えません", systemImage: "camera.fill")
        } description: {
            Text("設定でカメラを許可するか、実機で対面スキャンしてください。数列を目視で突き合わせても確認できます。")
        }
        .foregroundStyle(.white)
    }
}

// MARK: - AVFoundation preview

/// カメラ映像を表示し QR を検出する `UIViewControllerRepresentable`。
private struct CameraPreview: UIViewControllerRepresentable {
    let onFound: (String) -> Void
    /// 権限拒否・デバイス無しなどで撮影を開始できないときに呼ぶ。
    let onUnavailable: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.coordinator = context.coordinator
        controller.onUnavailable = onUnavailable
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    /// メタデータ出力の受け口。最初の QR だけを 1 度だけ上流へ渡す。
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onFound: (String) -> Void
        private var didFind = false

        init(onFound: @escaping (String) -> Void) {
            self.onFound = onFound
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didFind,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else { return }
            didFind = true
            DispatchQueue.main.async { [onFound] in onFound(value) }
        }
    }
}

/// AVCaptureSession を保持するコントローラ。権限確認 → 構成 → プレビュー表示を担う。
private final class ScannerViewController: UIViewController {
    weak var coordinator: CameraPreview.Coordinator?
    var onUnavailable: (() -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// 開始/停止をメインスレッドから外すためのキュー（AVFoundation 推奨）。
    private let sessionQueue = DispatchQueue(label: "DriftSonar.qrScanner.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestAccessAndConfigure()
    }

    private func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureSession() : self?.onUnavailable?()
                }
            }
        default:
            onUnavailable?()
        }
    }

    /// セッション構成（入出力の追加・開始）は AVFoundation 推奨どおり `sessionQueue` 上で行い、
    /// メインスレッドの瞬間フリーズと `session` への並行アクセスを避ける。プレビュー層の追加のみ
    /// メインへ戻す。
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // シミュレータやカメラ非搭載端末では device が nil。安全に案内へフォールバック。
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async { self.onUnavailable?() }
                return
            }
            self.session.beginConfiguration()
            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.onUnavailable?() }
                return
            }
            self.session.addOutput(output)
            output.setMetadataObjectsDelegate(self.coordinator, queue: DispatchQueue.main)
            // カメラ入力があるとき .qr は常にサポートされる。`availableMetadataObjectTypes` の
            // 評価タイミング差で空配列になり検出できなくなる事故を避け、直接指定する。
            output.metadataObjectTypes = [.qr]
            self.session.commitConfiguration()

            self.session.startRunning()

            DispatchQueue.main.async { self.installPreviewLayer() }
        }
    }

    private func installPreviewLayer() {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }
}
