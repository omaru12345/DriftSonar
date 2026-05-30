import SwiftData
import SwiftUI
import DriftSonarCore

struct SecretMessageView: View {
    @State private var viewModel: SecretMessageViewModel
    @Environment(\.modelContext) private var modelContext

    /// Optional nickname received via BLE (TASK-080). Falls back to fingerprint.
    private let peerNickname: String?

    init(otherPublicKey: Data, myPublicKey: Data, peerNickname: String? = nil) {
        _viewModel = State(initialValue: SecretMessageViewModel(
            otherPublicKey: otherPublicKey,
            myPublicKey: myPublicKey
        ))
        self.peerNickname = peerNickname
    }

    private var peerTitle: String {
        peerNickname ?? PublicKeyFingerprint.formatted(of: viewModel.otherPublicKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<viewModel.messages.count, id: \.self) { index in
                            let msg = viewModel.messages[index]
                            MessageBubble(text: msg.text, isMine: msg.isMine)
                                .id(index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .onChange(of: viewModel.messages.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("E2E 暗号化メッセージ...", text: $viewModel.draftMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(viewModel.draftMessage.isEmpty ? .gray : .blue)
                }
                .disabled(viewModel.draftMessage.isEmpty)
            }
            .padding()
        }
        .navigationTitle(peerTitle)
        .navigationBarTitleDisplayMode(.inline)
        // TASK-154: Unified error alert (key unavailable / encryption failed).
        .errorAlert(Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        ))
        .onAppear {
            viewModel.setup(
                repository: SwiftDataSecretMessageRepository(container: modelContext.container)
            )
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let text: String
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMine ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isMine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if !isMine { Spacer(minLength: 60) }
        }
    }
}
