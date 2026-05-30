import SwiftUI
import DriftSonarCore

struct ComposeView: View {
    let authorPublicKey: Data
    /// Called with (content, isAnonymous) when the user taps "投稿" (TASK-109/110).
    let onSubmit: (String, Bool) -> Void

    @State private var content = ""
    @State private var isAnonymous = false
    @State private var isPosting = false
    @Environment(\.dismiss) private var dismiss

    private let maxLength = CreatePostUseCase.maxContentLength

    private var remaining: Int { maxLength - content.count }
    private var isOverLimit: Bool { remaining < 0 }
    private var canPost: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOverLimit }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $content)
                    .frame(minHeight: 140)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Divider()

                HStack {
                    Text("\(remaining)")
                        .font(.caption)
                        .foregroundStyle(remaining < 20 ? (isOverLimit ? .red : .orange) : .secondary)
                        .padding(.leading, 16)
                    Spacer()
                    // TASK-109: Anonymous posting toggle.
                    Toggle(isOn: $isAnonymous) {
                        Label("匿名で投稿", systemImage: "person.fill.questionmark")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(.secondary)
                    .padding(.trailing, 16)
                }
                .padding(.vertical, 8)

                Spacer()
            }
            .navigationTitle("新しい投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // TASK-089: Show spinner while posting.
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("投稿") {
                            isPosting = true
                            onSubmit(content, isAnonymous)
                            isPosting = false
                            dismiss()
                        }
                        .bold()
                        .disabled(!canPost)
                    }
                }
            }
        }
    }
}
