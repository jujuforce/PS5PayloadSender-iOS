import Foundation

@MainActor
final class PayloadStore: ObservableObject {
    @Published private(set) var payloads: [Payload] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var folderURL: URL?

    var hasFolder: Bool { folderURL != nil }

    private static let bookmarkKey = "payloadFolderBookmark"
    private static let supportedExtensions: Set<String> = ["elf", "lua"]

    init() {
        restoreBookmark()
    }

    #if DEBUG
    init(preview payloads: [Payload]) {
        self.payloads = payloads
        self.isLoading = false
        self.folderURL = URL(fileURLWithPath: "/fake")
    }
    #endif

    // MARK: - Folder Selection

    func setFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            error = NSLocalizedString("error.folder.access", comment: "")
            return
        }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: Self.bookmarkKey)
        } catch {
            self.error = NSLocalizedString("error.folder.bookmark", comment: "")
        }

        folderURL = url
        loadPayloads()
    }

    func clearFolder() {
        if let url = folderURL {
            url.stopAccessingSecurityScopedResource()
        }
        folderURL = nil
        payloads = []
        error = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
    }

    // MARK: - Bookmark Restore

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            // ponytail: no saved folder → fall back to our own Documents dir, which
            // UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace publish as
            // "On My iPhone → PS5 Sender". Keeps the folder picker off the critical
            // path: a fresh install has somewhere to drop payloads without it.
            // No security scope needed — this is inside our own sandbox, and
            // setFolder() would reject it for exactly that reason.
            folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            loadPayloads()
            return
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        guard url.startAccessingSecurityScopedResource() else { return }

        if isStale {
            if let newData = try? url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(newData, forKey: Self.bookmarkKey)
            }
        }

        folderURL = url
        loadPayloads()
    }

    // MARK: - Load Payloads

    func loadPayloads() {
        guard let folderURL else {
            payloads = []
            return
        }

        isLoading = true
        error = nil

        let supportedExts = Self.supportedExtensions

        Task.detached(priority: .userInitiated) {
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )

                let discovered = urls
                    .filter { supportedExts.contains($0.pathExtension.lowercased()) }
                    .map { Payload(url: $0) }
                    .sorted {
                        if $0.fileExtension != $1.fileExtension {
                            return $0.fileExtension == "lua"
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }

                await MainActor.run {
                    self.payloads = discovered
                    self.isLoading = false
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    self.error = String(format: NSLocalizedString("error.folder.read", comment: ""), message)
                    self.payloads = []
                    self.isLoading = false
                }
            }
        }
    }
}
