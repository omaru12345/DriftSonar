import SwiftUI
import DriftSonarCore

struct ComposeView: View {
    let authorPublicKey: Data
    /// Called with (content, isAnonymous) when the user taps "投稿" (TASK-109/110).
    /// Returns `nil` on success, or an `AppError` to keep the sheet open and report (TASK-142).
    let onSubmit: (String, Bool) async -> AppError?

    @State private var content = ""
    @State private var isAnonymous = false
    @State private var isPosting = false
    /// Post failure surfaced in-sheet so it isn't hidden behind the dismissed sheet (TASK-142).
    @State private var postError: AppError?
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
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // TASK-089/142: Show the spinner for the duration of the post and only
                    // dismiss on success. Swapping the button for the spinner also blocks
                    // double submission.
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("投稿") { submit() }
                            .bold()
                            .disabled(!canPost)
                    }
                }
            }
            // TASK-142/154: Report a post failure in-sheet so it isn't hidden behind dismiss.
            .errorAlert($postError)
        }
    }

    /// Runs the post asynchronously, keeping the spinner visible until it completes,
    /// dismissing only on success and surfacing the error otherwise (TASK-142).
    private func submit() {
        Task {
            isPosting = true
            let result = await onSubmit(content, isAnonymous)
            isPosting = false
            if let result {
                postError = result
            } else {
                dismiss()
            }
        }
    }
}
