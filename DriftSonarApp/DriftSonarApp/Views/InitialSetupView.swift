import SwiftUI
import SwiftData
import DriftSonarCore

struct InitialSetupView: View {
    @Bindable var viewModel: InitialSetupViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("プロフィール情報")) {
                    TextField("ニックネーム（必須）", text: $viewModel.nickname)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("自己紹介（任意・100文字まで）", text: $viewModel.bio, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: {
                    viewModel.createProfile()
                }) {
                    Text("プロフィールを作成して鍵を生成")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .disabled(viewModel.nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("DriftSonar へようこそ")
        }
    }
}

#Preview {
    InitialSetupView(viewModel: InitialSetupViewModel())
}
