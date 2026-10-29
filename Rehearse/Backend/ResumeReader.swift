import Compression
import Foundation
import PDFKit
import UIKit
import Vision

/// Reads the text of a resume the candidate picked: a PDF's text, a text or
/// RTF file, or a photo's text found by Vision. Picking out projects needs a
/// language model, so for now only skills (by name) and the education line
/// are found; the text itself is kept for when projects can be read.
nonisolated enum ResumeReader {
    /// Where picked files are copied, so they can be read after the picker
    /// closes and its access to the original ends.
    static var uploadsFolder: URL {
        URL.temporaryDirectory.appending(path: "ResumeUploads", directoryHint: .isDirectory)
    }

    /// Copies a file the picker returned into `uploadsFolder`, under its own
    /// name. Returns false if it couldn't be read.
    @discardableResult
    static func keep(_ url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let folder = uploadsFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appending(path: url.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        return (try? FileManager.default.copyItem(at: url, to: destination)) != nil
    }

    /// The kept copy of a picked file, if there is one.
    static func keptFile(named fileName: String) -> URL? {
        let url = uploadsFolder.appending(path: fileName)
        return FileManager.default.fileExists(atPath: url.path()) ? url : nil
    }

    /// The resume's text and what could be found in it, or why it couldn't
    /// be read.
    @concurrent
    static func read(_ url: URL) async -> ResumeStatus {
        let fileName = url.lastPathComponent
        let text = await extractText(from: url).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 40 else {
            return .failed(fileName: fileName, reason: "We couldn’t find any text in this file. Try a PDF exported from your resume, or a clear photo of it.")
        }
        return .ready(ResumeContext(
            fileName: fileName,
            highlights: [],
            skills: skills(in: text),
            education: education(in: text),
            text: text
        ))
    }

    private static func extractText(from url: URL) async -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: url)?.string ?? ""
        case "txt", "text", "md":
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        case "rtf":
            let attributed = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            return attributed?.string ?? ""
        case "heic", "jpg", "jpeg", "png":
            return await recognizeText(in: url)
        case "docx":
            return wordText(at: url)
        default:
            // Word files and anything else: whatever plain text there is.
            let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil)
            return attributed?.string ?? ""
        }
    }

    /// A Word file's text: the body XML out of the zip it's packed in, one
    /// line per paragraph.
    static func wordText(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url),
              let xmlData = zipEntry(named: "word/document.xml", in: [UInt8](data)),
              let xml = String(data: xmlData, encoding: .utf8) else { return "" }
        var text = xml
            .replacingOccurrences(of: "</w:p>", with: "\n")
            .replacingOccurrences(of: "<w:tab/>", with: "\t")
            .replacingOccurrences(of: "<w:br/>", with: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, character) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&apos;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
    }

    /// One file out of a zip archive, read from its central directory.
    /// Handles the two methods Word uses: stored and deflated.
    private static func zipEntry(named name: String, in bytes: [UInt8]) -> Data? {
        func uint16(_ at: Int) -> Int { at + 1 < bytes.count ? Int(bytes[at]) | Int(bytes[at + 1]) << 8 : 0 }
        func uint32(_ at: Int) -> Int { uint16(at) | uint16(at + 2) << 16 }

        // The end-of-directory record, searched for from the end.
        guard bytes.count > 22 else { return nil }
        var end = bytes.count - 22
        while end >= max(0, bytes.count - 65_557), uint32(end) != 0x0605_4B50 { end -= 1 }
        guard end >= 0, uint32(end) == 0x0605_4B50 else { return nil }

        var entry = uint32(end + 16)
        for _ in 0..<uint16(end + 10) {
            guard uint32(entry) == 0x0201_4B50 else { return nil }
            let method = uint16(entry + 10)
            let compressedSize = uint32(entry + 20)
            let size = uint32(entry + 24)
            let nameLength = uint16(entry + 28)
            let headerOffset = uint32(entry + 42)
            let entryName = String(decoding: bytes[min(entry + 46, bytes.count)..<min(entry + 46 + nameLength, bytes.count)], as: UTF8.self)
            if entryName == name {
                guard uint32(headerOffset) == 0x0403_4B50 else { return nil }
                let start = headerOffset + 30 + uint16(headerOffset + 26) + uint16(headerOffset + 28)
                guard start + compressedSize <= bytes.count else { return nil }
                let packed = Array(bytes[start..<start + compressedSize])
                switch method {
                case 0:
                    return Data(packed)
                case 8:
                    var output = [UInt8](repeating: 0, count: max(size, 1))
                    let written = compression_decode_buffer(&output, output.count, packed, packed.count, nil, COMPRESSION_ZLIB)
                    return written > 0 ? Data(output[..<written]) : nil
                default:
                    return nil
                }
            }
            entry += 46 + nameLength + uint16(entry + 30) + uint16(entry + 32)
        }
        return nil
    }

    /// The text in a photo of a resume, line by line, top to bottom.
    private static func recognizeText(in url: URL) async -> String {
        guard let image = UIImage(contentsOfFile: url.path())?.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Skills a student resume commonly lists, matched as whole words.
    static let knownSkills = [
        "Swift", "SwiftUI", "UIKit", "Objective-C", "Kotlin", "Java", "Python", "JavaScript", "TypeScript",
        "Go", "Rust", "C++", "C#", "Ruby", "PHP", "Dart", "Flutter", "React", "React Native", "Angular", "Vue",
        "Node.js", "Django", "Flask", "Spring", "SQL", "PostgreSQL", "MySQL", "MongoDB", "Redis", "Firebase",
        "Supabase", "GraphQL", "REST", "Docker", "Kubernetes", "AWS", "Azure", "GCP", "Terraform", "Git",
        "Linux", "TensorFlow", "PyTorch", "Machine Learning", "Figma", "Core Data", "Combine", "Xcode",
    ]

    static func skills(in text: String) -> [String] {
        knownSkills.filter { skill in
            let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: skill) + "(?![A-Za-z0-9])"
            return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    /// The first line that names a degree or a college.
    static func education(in text: String) -> String? {
        let markers = ["b.tech", "btech", "b.e.", "bachelor", "b.sc", "bsc", "m.tech", "master", "university", "college", "institute"]
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { line in line.count <= 120 && markers.contains { line.lowercased().contains($0) } }
    }
}
