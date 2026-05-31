import SwiftData
import SwiftUI
import DriftSonarCore

struct SecretMessageView: View {
    @State private var viewModel: SecretMessageViewModel
    @Environment(\.modelContext) private var modelContext

    /// Optional nickname received via BLE (TASK-080). Falls back to fingerprint.
    private let peerNickname: String?

    init(otherPublicKey: Data, peerNickname: String? = nil) {
        _viewModel = State(initialValue: SecretMessageViewModel(
            otherPublicKey: otherPublicKey
        ))
        self.peerNickname = peerNickname
    }

    private var peerTitle: String {
        peerNickname ?? PublicKeyFingerprint.formatted(of: viewModel.otherPublicKey)
    }

    private var encryptionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            Text("端末間でエンドツーエンド暗号化されています")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
    }

    var body: some View {
        VStack(spacing: 0) {
            // TASK-141: E2E encryption reassurance badge (aligns with EP-025 verified badge).
            encryptionBadge

            if viewModel.messages.isEmpty {
                EmptyMessagesView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(0..<viewModel.messages.count, id: \.self) { index in
                                let msg = viewModel.messages[index]
                                MessageBubble(text: msg.text, isMine: msg.isMine, timestamp: msg.timestamp)
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
                        .foregroundStyle(viewModel.draftMessage.isEmpty ? .gray : .accentColor)
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
    let timestamp: Date

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                // TASK-141: Per-message send time below the bubble.
                Text(Self.timeLabel(for: timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }

    /// Time only for today, abbreviated date + time otherwise.
    private static func timeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - EmptyMessagesView

// TASK-141: Shown when no messages exist yet — reinforces the E2E "closed" positioning.
private struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor.opacity(0.6))
            Text("まだメッセージはありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("ここでのやり取りは端末間で\nエンドツーエンド暗号化され、\n二人の間だけに閉じます。")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
