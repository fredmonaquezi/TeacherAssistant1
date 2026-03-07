import SwiftUI
import SwiftData

struct UsefulLinksView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageManager: LanguageManager

    @Query(sort: \UsefulLink.sortOrder) private var usefulLinks: [UsefulLink]

    @State private var formTitle = ""
    @State private var formURL = ""
    @State private var formDescription = ""
    @State private var editingLinkID: UUID?
    @State private var showingEditorSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteLinkID: UUID?
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false

    private var isEditing: Bool {
        editingLinkID != nil
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if usefulLinks.isEmpty {
                    emptyStateCard
                } else {
                    ForEach(Array(usefulLinks.enumerated()), id: \.element.id) { index, link in
                        UsefulLinkRow(
                            link: link,
                            index: index,
                            totalCount: usefulLinks.count,
                            openAction: { open(link) },
                            editAction: { startEditing(link) },
                            moveUpAction: { move(linkID: link.id, direction: -1) },
                            moveDownAction: { move(linkID: link.id, direction: 1) },
                            deleteAction: { confirmDelete(link) }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
#if !os(macOS)
        .navigationTitle(languageManager.localized("Useful Links"))
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    startCreating()
                } label: {
                    Label(languageManager.localized("Add Link"), systemImage: "plus")
                }
            }
        }
        .appSheetBackground(tint: .mint)
        .sheet(isPresented: $showingEditorSheet) {
            linkEditorSheet
        }
        .alert(languageManager.localized("Delete Link?"), isPresented: $showingDeleteConfirmation) {
            Button(languageManager.localized("Cancel"), role: .cancel) {
                pendingDeleteLinkID = nil
            }
            Button(languageManager.localized("Delete"), role: .destructive) {
                deletePendingLink()
            }
        } message: {
            Text(languageManager.localized("This link will be removed from the app and future backups."))
        }
        .alert(languageManager.localized("Error"), isPresented: $showingErrorAlert) {
            Button(languageManager.localized("OK")) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var linkEditorSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PlatformSpacing.sectionSpacing) {
                    editorHeaderCard
                    editorFieldsCard
                    if !formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !formURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !formDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        editorPreviewCard
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .appSheetBackground(tint: .mint)
            .navigationTitle(isEditing ? languageManager.localized("Edit Link") : languageManager.localized("Add Link"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.localized("Cancel"), role: .cancel) {
                        showingEditorSheet = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? languageManager.localized("Save Changes") : languageManager.localized("Add Link")) {
                        submitForm()
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 520, minHeight: 480)
#endif
    }

    private var editorHeaderCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: isEditing ? "square.and.pencil.circle.fill" : "plus.circle.fill")
                .font(.title2)
                .foregroundColor(.mint)
                .frame(width: 42, height: 42)
                .appCardStyle(
                    cornerRadius: 12,
                    borderColor: Color.mint.opacity(0.16),
                    shadowOpacity: 0.02,
                    shadowRadius: 4,
                    shadowY: 1,
                    tint: .mint
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(isEditing ? languageManager.localized("Update Link Details") : languageManager.localized("Create a New Link"))
                    .font(AppTypography.sectionTitle)

                Text(languageManager.localized("Add a clear title, valid URL, and optional note to keep your resources organized."))
                    .font(.subheadline)
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.mint.opacity(0.12),
            tint: .mint
        )
    }

    private var editorFieldsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldSection(title: languageManager.localized("Title")) {
                TextField(languageManager.localized("e.g. Reading Portal"), text: $formTitle)
#if os(iOS)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
#endif
                    .font(.body)
                    .appFieldStyle(tint: .mint)
            }

            fieldSection(title: languageManager.localized("URL")) {
                TextField("https://example.com", text: $formURL)
#if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                    .font(.body)
                    .appFieldStyle(tint: .blue)
            }

            fieldSection(title: languageManager.localized("Description (optional)")) {
                TextEditor(text: $formDescription)
                    .frame(minHeight: 96)
                    .padding(8)
                    .font(.body)
                    .lineSpacing(2)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppChrome.elevatedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                    )
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.mint.opacity(0.12),
            tint: .mint
        )
    }

    private var editorPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageManager.localized("Preview"))
                .font(AppTypography.eyebrow)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? languageManager.localized("Untitled Link") : formTitle)
                .font(AppTypography.cardTitle)
                .lineSpacing(1)

            let domain = editorLinkDomain(formURL)
            if !domain.isEmpty {
                Text(domain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppChrome.elevatedBackground)
                    )
            }

            if !formDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(formDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .lineLimit(4)
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.mint.opacity(0.10),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .mint
        )
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageManager.localized("No useful links yet."))
                .font(AppTypography.cardTitle)
            Text(languageManager.localized("Tap Add Link to create your first website card."))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                startCreating()
            } label: {
                Label(languageManager.localized("Add Link"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.mint)
                    )
            }
        }
        .padding()
        .appCardStyle(
            cornerRadius: 16,
            borderColor: Color.mint.opacity(0.10),
            tint: .mint
        )
    }

    private func submitForm() {
        guard let sanitizedTitle = SecurityHelpers.sanitizeName(formTitle) else {
            presentError(languageManager.localized("Link title is required."))
            return
        }

        guard let sanitizedURL = normalizedHttpsURL(from: formURL) else {
            presentError(languageManager.localized("URL must start with https://"))
            return
        }

        let sanitizedDescription = SecurityHelpers.sanitizeNotes(formDescription)
        let now = Date()

        if let editingLinkID,
           let existingLink = usefulLinks.first(where: { $0.id == editingLinkID }) {
            existingLink.title = sanitizedTitle
            existingLink.url = sanitizedURL
            existingLink.linkDescription = sanitizedDescription
            existingLink.updatedAt = now
        } else {
            let nextSortOrder = (usefulLinks.map(\.sortOrder).max() ?? -1) + 1
            let newLink = UsefulLink(
                title: sanitizedTitle,
                url: sanitizedURL,
                linkDescription: sanitizedDescription,
                sortOrder: nextSortOrder,
                createdAt: now,
                updatedAt: now
            )
            context.insert(newLink)
        }

        let saveReason = isEditing ? "Save useful link edits" : "Create useful link"
        guard saveChanges(reason: saveReason) else { return }
        showingEditorSheet = false
        resetForm()
    }

    private func startCreating() {
        resetForm()
        showingEditorSheet = true
    }

    private func startEditing(_ link: UsefulLink) {
        editingLinkID = link.id
        formTitle = link.title
        formURL = link.url
        formDescription = link.linkDescription
        showingEditorSheet = true
    }

    private func confirmDelete(_ link: UsefulLink) {
        pendingDeleteLinkID = link.id
        showingDeleteConfirmation = true
    }

    private func deletePendingLink() {
        guard let pendingDeleteLinkID,
              let link = usefulLinks.first(where: { $0.id == pendingDeleteLinkID }) else {
            self.pendingDeleteLinkID = nil
            return
        }

        let remainingLinks = usefulLinks.filter { $0.id != link.id }
        context.delete(link)
        resequence(remainingLinks)
        _ = saveChanges(reason: "Delete useful link")

        if editingLinkID == pendingDeleteLinkID {
            showingEditorSheet = false
            resetForm()
        }

        self.pendingDeleteLinkID = nil
    }

    private func move(linkID: UUID, direction: Int) {
        guard let currentIndex = usefulLinks.firstIndex(where: { $0.id == linkID }) else { return }
        let targetIndex = currentIndex + direction

        guard usefulLinks.indices.contains(targetIndex) else { return }

        var reorderedLinks = usefulLinks
        reorderedLinks.swapAt(currentIndex, targetIndex)
        resequence(reorderedLinks)
        _ = saveChanges(reason: "Reorder useful links")
    }

    private func resequence(_ links: [UsefulLink]) {
        let now = Date()
        for (index, link) in links.enumerated() {
            link.sortOrder = index
            link.updatedAt = now
        }
    }

    private func open(_ link: UsefulLink) {
        guard let url = URL(string: link.url) else {
            presentError(languageManager.localized("This link is not valid anymore. Please edit it and try again."))
            return
        }

        openURL(url)
    }

    private func resetForm() {
        editingLinkID = nil
        formTitle = ""
        formURL = ""
        formDescription = ""
    }

    private func saveChanges(reason: String) -> Bool {
        SaveCoordinator.save(
            context: context,
            reason: reason
        )
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }

    private func normalizedHttpsURL(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("https://"),
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else {
            return nil
        }

        return url.absoluteString
    }

    private func editorLinkDomain(_ rawValue: String) -> String {
        guard let url = URL(string: rawValue),
              let host = url.host else {
            return ""
        }
        return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}

private struct UsefulLinkRow: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let link: UsefulLink
    let index: Int
    let totalCount: Int
    let openAction: () -> Void
    let editAction: () -> Void
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openAction) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(link.title)
                            .font(AppTypography.cardTitle)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }

                    let domain = linkDomain(link.url)
                    if !domain.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                            Text(domain)
                        }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppChrome.elevatedBackground)
                            )
                    }

                    if !link.linkDescription.isEmpty {
                        Text(link.linkDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: editAction) {
                    actionIcon("pencil")
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Edit"))

                Button(action: moveUpAction) {
                    actionIcon("arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .help(languageManager.localized("Move Up"))

                Button(action: moveDownAction) {
                    actionIcon("arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(index == totalCount - 1)
                .help(languageManager.localized("Move Down"))

                Spacer()

                Button(role: .destructive, action: deleteAction) {
                    actionIcon("trash")
                }
                .buttonStyle(.plain)
                .help(languageManager.localized("Delete"))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .appCardStyle(
            cornerRadius: 12,
            borderColor: Color.mint.opacity(0.12),
            shadowOpacity: 0.03,
            shadowRadius: 5,
            shadowY: 2,
            tint: .mint
        )
    }

    private func linkDomain(_ rawValue: String) -> String {
        guard let url = URL(string: rawValue),
              let host = url.host else {
            return rawValue
        }

        return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    private func actionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppChrome.elevatedBackground)
            )
    }
}

#Preview {
    UsefulLinksView()
        .environmentObject(LanguageManager())
}
