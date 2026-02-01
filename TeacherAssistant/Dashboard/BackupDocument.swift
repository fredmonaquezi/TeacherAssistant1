import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.data] }

    var data: Data

    init(url: URL?) {
        if let url, let data = try? Data(contentsOf: url) {
            self.data = data
        } else {
            self.data = Data()
        }
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}
