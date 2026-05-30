import SwiftUI
import SwiftData
import DriftSonarCore

struct InitialSetupView: View {
    @Bindable var viewModel: InitialSetupViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Nickname (Required)", text: $viewModel.nickname)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    TextField("Bio (Optional, max 100 chars)", text: $viewModel.bio, axis: .vertical)
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
                    Text("Create Profile & Generate Keys")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .disabled(viewModel.nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Welcome to DriftSonar")
        }
    }
}

#Preview {
    InitialSetupView(viewModel: InitialSetupViewModel())
}
