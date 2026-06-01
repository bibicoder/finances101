import SwiftUI

struct ConnectBankView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(AppColors.primaryDeep)

                VStack(spacing: 10) {
                    Text("Connect Your Bank")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Securely import transactions using Plaid.\nYour credentials are never stored in the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await connectBank() }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Label("Connect Bank Account", systemImage: "link")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primaryDeep)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading)

                    Text("Powered by Plaid · Bank-level encryption")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showImport) {
                PlaidImportView()
                    .onDisappear { dismiss() }
            }
        }
    }

    private func connectBank() async {
        isLoading = true
        errorMessage = nil
        do {
            let linkToken = try await PlaidService.createLinkToken()
            await MainActor.run {
                PlaidLinkPresenter.open(
                    token: linkToken,
                    onSuccess: { publicToken, bankName in
                        Task { await handleSuccess(publicToken: publicToken, bankName: bankName) }
                    },
                    onExit: {
                        isLoading = false
                    }
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func handleSuccess(publicToken: String, bankName: String) async {
        do {
            let accessToken = try await PlaidService.exchangePublicToken(publicToken)
            PlaidManager.shared.saveConnection(accessToken: accessToken, bankName: bankName)
            HapticManager.success()
            showImport = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
