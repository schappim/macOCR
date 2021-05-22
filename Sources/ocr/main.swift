import Foundation
import Cocoa
import func Darwin.fputs
import var Darwin.stderr

func run() -> Error? {
    let args = CLIArgs.ocr.parseOrExit()
    let tempDirectory = "/tmp/macOCR"
    do {
        try FileManager.default
            .createDirectory(atPath: tempDirectory, withIntermediateDirectories: false, attributes: nil)
    } catch {}
    let tempFilePath = "\(tempDirectory)/\(UUID().uuidString).png"
    defer {
        try! FileManager.default.removeItem(atPath: tempFilePath)
    }
    let regionUrl = captureRegion(destination: URL(fileURLWithPath: tempFilePath))
    let error = detectText(imageFile: regionUrl) { text in
        guard let text = text else {
            fputs("Error: no text could be detected", stderr)
            try! FileManager.default.removeItem(atPath: tempFilePath)
            exit(EXIT_FAILURE)
        }
        print(text)
        if args.copy {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
        }
    }
    switch error {
    case nil:
        return nil
    case .imageHandlerError(let error):
        return error
    case .invalidImage:
        return OCRError.invalidImage
    }
}

if let error = run() {
    fputs(error.localizedDescription, stderr)
    exit(EXIT_FAILURE)
} else {
    exit(EXIT_SUCCESS)
}
