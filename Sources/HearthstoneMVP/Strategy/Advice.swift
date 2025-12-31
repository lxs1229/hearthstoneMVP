import Foundation

struct Advice: Equatable {
    var headline: String
    var details: [String]
}

extension Advice {
    static let empty = Advice(headline: "等待识别中…", details: [])
}
