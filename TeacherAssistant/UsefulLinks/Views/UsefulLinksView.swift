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
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteLinkID: UUID?
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false

    private var isEditing: Bool {
        editingLinkID != nil
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(languageManager.localized("Useful Links"))
                        .font(.headline)
                    Text(languageManager.localized("Store classroom links, open them quickly, and keep them in the order you need."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(isEditing ? languageManager.localized("Edit Link") : languageManager.localized("Add Link")) {
                TextField(languageManager.localized("Title"), text: $formTitle)
#if os(iOS)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
#endif

                TextField("https://example.com", text: $formURL)
#if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif

                TextField(languageManager.localized("Description (optional)"), text: $formDescription, axis: .vertical)
                    .lineLimit(2...4)

                HStack {
                    Button(isEditing ? languageManager.localized("Save Changes") : languageManager.localized("Add Link")) {
                        submitForm()
                    }

                    if isEditing {
                        Button(languageManager.localized("Cancel"), role: .cancel) {
                            resetForm()
                        }
                    }
                }
            }

            Section(languageManager.localized("Saved Links")) {
                if usefulLinks.isEmpty {
                    Text(languageManager.localized("No useful links yet. Add one above to get started."))
                        .foregroundStyle(.secondary)
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
        }
#if !os(macOS)
        .navigationTitle(languageManager.localized("Useful Links"))
#endif
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

        saveContext()
        resetForm()
    }

    private func startEditing(_ link: UsefulLink) {
        editingLinkID = link.id
        formTitle = link.title
        formURL = link.url
        formDescription = link.linkDescription
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
        saveContext()

        if editingLinkID == pendingDeleteLinkID {
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
        saveContext()
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

    private func saveContext() {
        do {
            try context.save()
        } catch {
            presentError(error.localizedDescription)
        }
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
}

private struct UsefulLinkRow: View {
    let link: UsefulLink
    let index: Int
    let totalCount: Int
    let openAction: () -> Void
    let editAction: () -> Void
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: openAction) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(link.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    let domain = linkDomain(link.url)
                    if !domain.isEmpty {
                        Text(domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button(action: moveUpAction) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button(action: moveDownAction) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(index == totalCount - 1)

                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func linkDomain(_ rawValue: String) -> String {
        guard let url = URL(string: rawValue),
              let host = url.host else {
            return rawValue
        }

        return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}

#Preview {
    UsefulLinksView()
        .environmentObject(LanguageManager())
}
