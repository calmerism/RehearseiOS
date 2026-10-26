import SwiftUI
import UniformTypeIdentifiers

/// The three ways a resume gets into Rehearse: a file from Files (which also
/// reaches iCloud Drive, Google Drive and the rest), a scan of a printed
/// copy, or one written for the candidate from their own notes.
enum ResumeSource: CaseIterable, Identifiable {
    case file, scan, build

    var id: Self { self }

    var title: String {
        switch self {
        case .file: "Choose a File"
        case .scan: "Scan a Paper Copy"
        case .build: "Build One for Me"
        }
    }

    var detail: String {
        switch self {
        case .file: "PDF or Word, from Files"
        case .scan: "With your camera"
        case .build: "Written from your notes"
        }
    }

    var symbol: String {
        switch self {
        case .file: "folder"
        case .scan: "doc.viewfinder"
        case .build: "square.and.pencil"
        }
    }

    /// What the Files picker offers. Photos are allowed so a photo of a
    /// resume shows why it can't be read.
    static let fileTypes: [UTType] = [.pdf, .rtf, .plainText, .image]
        + [UTType("org.openxmlformats.wordprocessingml.document"), UTType("com.microsoft.word.doc")].compactMap { $0 }
}

/// The three ways, as rows with what each one means beneath.
struct ResumeSourceRows: View {
    let choose: (ResumeSource) -> Void

    var body: some View {
        ForEach(ResumeSource.allCases) { source in
            Button {
                choose(source)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                        Text(source.detail)
                            .font(.subheadline)
                            // Gray, not the button's tint faded.
                            .foregroundStyle(Color.secondary)
                    }
                } icon: {
                    Image(systemName: source.symbol)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

/// The three ways, for a menu.
struct ResumeSourceMenuItems: View {
    let choose: (ResumeSource) -> Void

    var body: some View {
        ForEach(ResumeSource.allCases) { source in
            Button(source.title, systemImage: source.symbol) { choose(source) }
        }
    }
}

extension View {
    /// Opens the chosen way: the system Files picker, the scanner, or the
    /// builder. A picked or scanned file's name comes back to be read; a
    /// built resume saves itself to the Profile.
    func resumeSources(_ source: Binding<ResumeSource?>, read: @escaping (String) -> Void) -> some View {
        modifier(ResumeSourcePresenter(source: source, read: read))
    }
}

private struct ResumeSourcePresenter: ViewModifier {
    @Binding var source: ResumeSource?
    let read: (String) -> Void

    private func showing(_ wanted: ResumeSource) -> Binding<Bool> {
        Binding(
            get: { source == wanted },
            set: { if !$0, source == wanted { source = nil } }
        )
    }

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: showing(.file), allowedContentTypes: ResumeSource.fileTypes) { result in
                // Kept as a copy so it can be read after the picker closes.
                if case .success(let url) = result {
                    ResumeReader.keep(url)
                    read(url.lastPathComponent)
                }
            }
            .fullScreenCover(isPresented: showing(.scan)) {
                ResumeScannerView { read("Scanned Resume.pdf") }
            }
            .sheet(isPresented: showing(.build)) {
                ResumeBuilderView()
            }
    }
}
