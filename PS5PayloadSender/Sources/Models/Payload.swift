import Foundation

struct Payload: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let fileExtension: String

    var defaultPort: UInt16 {
        fileExtension == "lua" ? 9026 : 9021
    }

    var fullFilename: String { url.lastPathComponent }

    var data: Data? {
        try? Data(contentsOf: url)
    }

    init(url: URL) {
        self.url = url
        self.fileExtension = url.pathExtension.lowercased()
        self.name = url.deletingPathExtension().lastPathComponent
        self.id = url.lastPathComponent
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Payload, rhs: Payload) -> Bool {
        lhs.id == rhs.id
    }

    #if DEBUG
    static let preview: [Payload] = [
        Payload(url: URL(fileURLWithPath: "/fake/poops_ps5.lua")),
        Payload(url: URL(fileURLWithPath: "/fake/kstuff.elf")),
        Payload(url: URL(fileURLWithPath: "/fake/ftpsrv-ps5.elf")),
        Payload(url: URL(fileURLWithPath: "/fake/websrv-ps5.elf")),
        Payload(url: URL(fileURLWithPath: "/fake/shadowmountplus.elf")),
        Payload(url: URL(fileURLWithPath: "/fake/kstuff-toggle-all.elf")),
    ]
    #endif
}
