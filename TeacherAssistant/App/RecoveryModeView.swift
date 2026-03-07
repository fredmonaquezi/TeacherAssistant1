import SwiftUI
import UniformTypeIdentifiers

struct RecoveryModeView: View {
    @ObservedObject var coordinator: AppBootstrapCoordinator

    @State private var showingBackupImporter = false
    @State private var showingFreshStoreConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recovery Mode")
                .font(.largeTitle.weight(.semibold))

            Text(
                "The primary data store could not be opened. Your original store has been left untouched. Choose how you want to recover."
            )
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Startup Error")
                    .font(.headline)

                Text(coordinator.startupFailureDescription ?? "Unknown error")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text("Latest Local Snapshot")
                    .font(.headline)

                if let latestLocalSnapshotURL = coordinator.latestLocalSnapshotURL {
                    Text(latestLocalSnapshotURL.lastPathComponent)
                    Text(latestLocalSnapshotURL.path)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("No automatic or pre-restore snapshot was found.")
                        .foregroundStyle(.secondary)
                }
            }

            if coordinator.isRecoveryActionInProgress {
                ProgressView("Working...")
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                Button("Retry Primary Store") {
                    coordinator.retryOpeningPrimaryStore()
                }

                Button("Use Latest Local Snapshot") {
                    coordinator.restoreFromLatestLocalSnapshot()
                }
                .disabled(coordinator.latestLocalSnapshotURL == nil || coordinator.isRecoveryActionInProgress)

                Button("Import Backup File") {
                    showingBackupImporter = true
                }
                .disabled(coordinator.isRecoveryActionInProgress)

                Button("Create Fresh Empty Store", role: .destructive) {
                    showingFreshStoreConfirmation = true
                }
                .disabled(coordinator.isRecoveryActionInProgress)
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: 720, maxHeight: .infinity, alignment: .topLeading)
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [UTType(filenameExtension: "backup") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                coordinator.importBackup(from: url)
            case .failure(let error):
                let appError = AppError.recovery(
                    action: .selectBackupFile,
                    underlyingError: error
                )
                coordinator.recoveryMessage = appError.messageForAlert
            }
        }
        .confirmationDialog(
            "Create a fresh empty store?",
            isPresented: $showingFreshStoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Create Fresh Store", role: .destructive) {
                coordinator.createFreshStore()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Use this only if you want to start with empty data. Your broken primary store will remain on disk.")
        }
        .alert(
            "Recovery Error",
            isPresented: Binding(
                get: { coordinator.recoveryMessage != nil },
                set: { if !$0 { coordinator.recoveryMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(coordinator.recoveryMessage ?? "")
        }
    }
}

#Preview {
    RecoveryModeView(coordinator: AppBootstrapCoordinator())
}
