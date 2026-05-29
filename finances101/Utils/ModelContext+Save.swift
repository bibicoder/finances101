import SwiftData

extension ModelContext {
    func saveWithLogging(file: String = #file, line: Int = #line) {
        do {
            try save()
        } catch {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            print("[SwiftData] Save failed at \(fileName):\(line) – \(error.localizedDescription)")
        }
    }
}
