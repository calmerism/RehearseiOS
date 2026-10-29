import SwiftUI

/// A resume as a page, the way Files and Pages show documents: a real
/// miniature of its contents with the name underneath. Versions differ in
/// which project leads, so the miniature shows the difference at a glance.
/// Tapping selects it; the selected page gets an accent ring and a check,
/// as in Photos.
struct ResumeThumbnail: View {
    let context: ResumeContext
    let title: String
    var subtitle: String?
    var isSelected = false
    /// Shows a spinner over the page while a file is read.
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                ResumePage(context: context)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.ultraThinMaterial, in: .rect(cornerRadius: ResumePage.cornerRadius))
                        }
                    }
                    .selectionRing(isSelected)
                ThumbnailCaption(title: title, subtitle: subtitle)
            }
            .frame(width: ResumePage.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(ThumbnailButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The tile after the pages that adds one: an empty page with a symbol,
/// like the blank template in Pages.
struct ResumeAddTile: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                RoundedRectangle(cornerRadius: ResumePage.cornerRadius, style: .continuous)
                    .fill(AppTheme.fill)
                    .frame(width: ResumePage.width, height: ResumePage.height)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(AppTheme.brand)
                    }
                ThumbnailCaption(title: title, subtitle: subtitle)
            }
            .frame(width: ResumePage.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(ThumbnailButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// A horizontal shelf of pages that runs edge to edge inside a list, with
/// its first page on the cards' margin.
struct ResumeShelf<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                content
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

// MARK: - Page

/// A resume's first page in miniature. It's laid out at a readable size and
/// scaled down, so it reads as a real page rather than gray placeholder bars.
/// Paper is white in dark mode too, as documents are.
struct ResumePage: View {
    let context: ResumeContext
    /// Shelves use the standard size; a preview draws it larger, a row's
    /// icon smaller.
    var width: CGFloat = ResumePage.width
    /// Grows past the page's foot to fit everything, rather than cutting the
    /// last lines off: for a preview someone is checking line by line.
    var showsAll = false
    @State private var contentHeight: CGFloat = 0

    static let width: CGFloat = 108
    static var height: CGFloat { width * 11 / 8.5 }
    static let cornerRadius: CGFloat = 8
    /// The width the page is laid out at before scaling.
    private static let layoutWidth: CGFloat = 216

    var body: some View {
        let scale = width / Self.layoutWidth
        let radius = Self.cornerRadius * min(max(width / Self.width, 0.6), 1.6)
        let pageHeight = Self.layoutWidth * 11 / 8.5
        let layoutHeight = showsAll ? max(pageHeight, contentHeight) : pageHeight
        page
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            .frame(width: Self.layoutWidth, height: layoutHeight, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width, height: layoutHeight * scale, alignment: .topLeading)
            .background(.white)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 6 * min(width / Self.width, 2), y: 3 * min(width / Self.width, 2))
            .environment(\.colorScheme, .light)
            .accessibilityHidden(true)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context.name ?? MockData.candidateName)
                    .font(.system(size: 17, weight: .bold))
                Text(context.skills.prefix(4).joined(separator: ", "))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            Rectangle()
                .fill(AppTheme.brand)
                .frame(height: 1.5)
            if let education = context.education {
                Text("EDUCATION")
                    .font(.system(size: 7.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(education)
                    .font(.system(size: 8))
                    .lineLimit(2)
            }
            Text("PROJECTS")
                .font(.system(size: 7.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            ForEach(context.highlights) { highlight in
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(highlight.title)
                        .font(.system(size: 10, weight: .semibold))
                    Text(highlight.source)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(highlight.detail)
                        .font(.system(size: 8))
                        .lineLimit(showsAll ? nil : 3)
                }
            }
        }
        .foregroundStyle(.black)
        .lineLimit(1)
        .padding(16)
        // At its own height, so a long resume runs off the page's foot
        // rather than squeezing its lines.
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A resume as a full page, the width of the screen, as Files shows a PDF.
/// A resume written from notes has no file to open, so its page is drawn.
struct ResumePreviewSheet: View {
    let context: ResumeContext
    /// What's being previewed, as the bar's title.
    var title = "Preview"
    /// The reminder under a page written from notes; nil for one that isn't.
    var note: String? = "Written from your notes. Check each line is true."
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.md) {
                        ResumePage(context: context, width: min(proxy.size.width - 2 * AppTheme.Spacing.md, AppTheme.maxPageWidth), showsAll: true)
                        if let note {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity)
                }
            }
            .groupedBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A whole page as wide as the space it's given, every line showing: for
/// reading a resume where it sits, with no sheet to open.
struct FittedResumePage: View {
    let context: ResumeContext
    @State private var width: CGFloat = 0

    var body: some View {
        ResumePage(context: context, width: max(width, 1), showsAll: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

// MARK: - Pieces

private struct ThumbnailCaption: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
    }
}

/// Pages dim slightly when pressed, like a cell, and never tint their text.
private struct ThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private extension View {
    /// An accent ring a little outside the page, with a check at its corner.
    func selectionRing(_ isSelected: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: ResumePage.cornerRadius + 4, style: .continuous)
                .strokeBorder(AppTheme.brand, lineWidth: 2.5)
                .padding(-5)
                .opacity(isSelected ? 1 : 0)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, AppTheme.brand)
                .background(Circle().fill(.white).padding(2))
                .padding(6)
                .scaleEffect(isSelected ? 1 : 0.5)
                .opacity(isSelected ? 1 : 0)
        }
        .animation(.snappy(duration: 0.25), value: isSelected)
    }
}

#Preview {
    List {
        ResumeShelf {
            ResumeThumbnail(context: MockData.resume, title: "Original", subtitle: "From Profile", isSelected: true) {}
            ResumeThumbnail(context: MockData.tailoredVersions(company: "Apple", role: "Software Engineer")[0].context, title: "Apple", subtitle: "Leads with Campus Eats") {}
            ResumeAddTile(title: "Upload File", systemImage: "plus") {}
        }
    }
}
