import SwiftUI
import UniformTypeIdentifiers

// MARK: - Color Compat

extension Color {
    /// Adaptive cyan: bright in dark mode, darker teal-blue in light mode so it stays
    /// legible on white backgrounds. Uses UIColor adaptive init (iOS 13+).
    static var cyanCompat: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)   // bright cyan
                : UIColor(red: 0, green: 0.45, blue: 0.70, alpha: 1) // dark teal-blue
        })
    }

    /// Fixed #007AFF across all OS versions — avoids iOS 26's adaptive blue which renders
    /// significantly lighter/more vibrant in dark mode.
    static let appBlue = Color(red: 0, green: 122 / 255, blue: 1)
}

// MARK: - Font Compat

extension Font {
    /// `Font.title3` was added in iOS 14. Falls back to `.headline` on iOS 13.
    static var title3Compat: Font {
        if #available(iOS 14, *) { return .title3 }
        return .headline
    }
}

// MARK: - View Compat Modifiers

extension View {
    /// Dismisses the keyboard when scrolling, on iOS 16+. No-op on earlier versions.
    @ViewBuilder
    func scrollDismissesKeyboardCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }

    /// Allows bounce only when content overflows the scroll view (iOS 16.4+ / macOS 13.3+).
    @ViewBuilder
    func scrollBounceBasedOnSize() -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    /// Cross-version safe area ignore: uses `.ignoresSafeArea()` on iOS 14+,
    /// `.edgesIgnoringSafeArea(.all)` on iOS 13.
    @ViewBuilder
    func ignoresSafeAreaCompat() -> some View {
        if #available(iOS 14, *) {
            self.ignoresSafeArea()
        } else {
            self.edgesIgnoringSafeArea(.all)
        }
    }

    /// Cross-version navigation title: `.navigationTitle` on iOS 14+,
    /// `.navigationBarTitle` on iOS 13.
    @ViewBuilder
    func navigationTitleCompat(_ title: LocalizedStringKey) -> some View {
        if #available(iOS 14, *) {
            self.navigationTitle(title)
        } else {
            self.navigationBarTitle(title)
        }
    }

    /// Forces an inline navigation title on macOS Catalyst, where the large title
    /// collapses on short content. No-op on other platforms or on iOS 13 (not reachable
    /// via Catalyst anyway, but guards the iOS 14-only API for the compiler).
    @ViewBuilder
    func inlineTitleOnMac() -> some View {
        #if targetEnvironment(macCatalyst)
        if #available(iOS 14, *) {
            self.navigationBarTitleDisplayMode(.inline)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Spinner (cross-version)

/// Cross-version indeterminate spinner.
/// Uses `ProgressView` on iOS 14+, `UIActivityIndicatorView` on iOS 13.
struct SpinnerView: View {
    var body: some View {
        if #available(iOS 14, *) {
            ProgressView()
        } else {
            _ActivityIndicator()
        }
    }
}

private struct _ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let v = UIActivityIndicatorView(style: .medium)
        v.startAnimating()
        return v
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

// MARK: - Folder Picker (iOS 13)

/// Document picker for folders, used as a sheet on iOS 13 where `.fileImporter` is unavailable.
private struct FolderPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
        }
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPicker
        init(_ parent: FolderPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            urls.first.map(parent.onPick)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Folder Importer

extension View {
    /// Presents a folder picker. Uses `.fileImporter` on iOS 14+,
    /// falls back to a UIDocumentPickerViewController sheet on iOS 13.
    @ViewBuilder
    func folderImporter(isPresented: Binding<Bool>, onPick: @escaping (URL) -> Void) -> some View {
        if #available(iOS 14, *) {
            self.fileImporter(isPresented: isPresented, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { onPick(url) }
            }
        } else {
            self.sheet(isPresented: isPresented) {
                FolderPicker(isPresented: isPresented, onPick: onPick)
            }
        }
    }
}

// MARK: - Navigation Folder Toolbar

/// Toolbar modifier for iOS 14+: uses `.toolbar` with `Menu`.
@available(iOS 14, *)
private struct FolderToolbar14: ViewModifier {
    @ObservedObject var store: PayloadStore
    @Binding var showFolderPicker: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.hasFolder {
                    Button { store.loadPayloads() } label: {
                        Image(systemName: "arrow.clockwise")
                            .padding(10)
                            .contentShape(Rectangle())
                    }
                    Menu {
                        Button { showFolderPicker = true } label: {
                            Label("folder.menu.change", systemImage: "folder")
                        }
                        disconnectButton
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .padding(10)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var disconnectButton: some View {
        if #available(iOS 15, *) {
            Button(role: .destructive) { store.clearFolder() } label: {
                Label("folder.menu.disconnect", systemImage: "folder.badge.minus")
            }
        } else {
            Button { store.clearFolder() } label: {
                Label("folder.menu.disconnect", systemImage: "folder.badge.minus")
                    .foregroundColor(.red)
            }
        }
    }
}

/// Toolbar modifier dispatcher: `FolderToolbar14` on iOS 14+,
/// `.navigationBarItems` + action-sheet trigger on iOS 13.
private struct FolderToolbarModifier: ViewModifier {
    @ObservedObject var store: PayloadStore
    @Binding var showFolderPicker: Bool
    @Binding var showFolderActions: Bool

    func body(content: Content) -> some View {
        if #available(iOS 14, *) {
            content.modifier(FolderToolbar14(store: store, showFolderPicker: $showFolderPicker))
        } else {
            content.navigationBarItems(trailing: ios13Buttons)
        }
    }

    @ViewBuilder
    private var ios13Buttons: some View {
        if store.hasFolder {
            HStack(spacing: 4) {
                Button { store.loadPayloads() } label: {
                    Image(systemName: "arrow.clockwise")
                        .padding(10)
                        .contentShape(Rectangle())
                }
                Button { showFolderActions = true } label: {
                    Image(systemName: "ellipsis.circle")
                        .padding(10)
                        .contentShape(Rectangle())
                }
            }
        }
    }
}

extension View {
    func navFolderToolbar(
        store: PayloadStore,
        showFolderPicker: Binding<Bool>,
        showFolderActions: Binding<Bool>
    ) -> some View {
        modifier(FolderToolbarModifier(
            store: store,
            showFolderPicker: showFolderPicker,
            showFolderActions: showFolderActions
        ))
    }
}
