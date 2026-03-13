import SwiftUI
import UniformTypeIdentifiers

struct RecoveryModeView: View {
    @Environment(\.appMotionContext) private var motion
    @ObservedObject var coordinator: AppBootstrapCoordinator

    @State private var showingBackupImporter = false
    @State private var showingFreshStoreConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recovery Mode")
                        .font(.largeTitle.weight(.semibold))

                    Text(
                        "The primary data store could not be opened. Your original store has been left untouched. Choose how you want to recover."
                    )
                    .foregroundStyle(.secondary)
                }
                .appMotionReveal(index: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Startup Error")
                        .font(.headline)

                    Text(coordinator.startupFailureDescription ?? "Unknown error")
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: AppChrome.separator,
                    shadowOpacity: 0.03,
                    shadowRadius: 5,
                    shadowY: 2
                )
                .appMotionReveal(index: 1)

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
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: Color.blue.opacity(0.14),
                    shadowOpacity: 0.03,
                    shadowRadius: 5,
                    shadowY: 2,
                    tint: .blue
                )
                .appMotionReveal(index: 2)

                if coordinator.isRecoveryActionInProgress {
                    ProgressView("Working...")
                        .padding(.top, 4)
                        .transition(motion.transition(.inlineChange))
                }

                VStack(alignment: .leading, spacing: 12) {
                    recoveryActionButton("Retry Primary Store", systemImage: "arrow.clockwise.circle.fill", tint: .indigo) {
                        coordinator.retryOpeningPrimaryStore()
                    }

                    recoveryActionButton(
                        "Use Latest Local Snapshot",
                        systemImage: "clock.badge.checkmark.fill",
                        tint: .green,
                        isDisabled: coordinator.latestLocalSnapshotURL == nil || coordinator.isRecoveryActionInProgress
                    ) {
                        coordinator.restoreFromLatestLocalSnapshot()
                    }

                    recoveryActionButton(
                        "Import Backup File",
                        systemImage: "square.and.arrow.down.fill",
                        tint: .blue,
                        isDisabled: coordinator.isRecoveryActionInProgress
                    ) {
                        showingBackupImporter = true
                    }

                    recoveryActionButton(
                        "Create Fresh Empty Store",
                        systemImage: "trash.slash.fill",
                        tint: .red,
                        isDisabled: coordinator.isRecoveryActionInProgress,
                        isDestructive: true
                    ) {
                        showingFreshStoreConfirmation = true
                    }
                }
                .appMotionReveal(index: 3)

                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: 720, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppChrome.canvasBackground.ignoresSafeArea())
        .animation(motion.animation(.standard), value: coordinator.isRecoveryActionInProgress)
        .animation(motion.animation(.standard), value: coordinator.latestLocalSnapshotURL?.path)
        .animation(motion.animation(.standard), value: coordinator.startupFailureDescription)
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

    private func recoveryActionButton(
        _ title: String,
        systemImage: String,
        tint: Color,
        isDisabled: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 24)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(isDestructive ? Color.red : Color.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle(
                cornerRadius: 12,
                borderColor: tint.opacity(0.16),
                shadowOpacity: 0.03,
                shadowRadius: 4,
                shadowY: 1,
                tint: tint
            )
            .opacity(isDisabled ? 0.6 : 1)
        }
        .buttonStyle(AppPressableButtonStyle())
        .disabled(isDisabled)
    }
}

#Preview {
    RecoveryModeView(coordinator: AppBootstrapCoordinator())
}
