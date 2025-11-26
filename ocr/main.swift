import Cocoa
import Vision
import ArgumentParserKit

var joiner = " "
var bigSur = false
if #available(OSX 11, *) {
    bigSur = true
}

var recognitionLanguages = ["en-US"]
let inputURL = URL(fileURLWithPath: "/tmp/ocr.png")

// --- OCR Functions ---

func recognizeTextHandler(request: VNRequest, error: Error?) {
    guard let observations = request.results as? [VNRecognizedTextObservation] else {
        print("Error: Could not cast Vision request results.")
        NSApp.terminate(nil)
        return
    }

    print("Found \(observations.count) text observations.")

    let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }

    if recognizedStrings.isEmpty {
        print("Warning: No text recognized.")
    } else {
        let joined = recognizedStrings.joined(separator: joiner)
        print("Recognized Text: \"\(joined)\"")
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        let success = pasteboard.setString(joined, forType: .string)
        if success {
            print("Successfully copied text to clipboard.")
        } else {
            print("Error: Failed to copy text to clipboard.")
        }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.terminate(nil)
    }
}

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent)
}

func detectText(from url: URL) {
    guard let ciImage = CIImage(contentsOf: url) else {
        print("Could not load image from \(url)")
        NSApp.terminate(nil)
        return
    }
    guard let cgImage = convertCIImageToCGImage(inputImage: ciImage) else {
        print("Could not convert CIImage to CGImage")
        NSApp.terminate(nil)
        return
    }
    
    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
    let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
    request.recognitionLanguages = recognitionLanguages
    
    do {
        try requestHandler.perform([request])
    } catch {
        print("Unable to perform the Vision request: \(error).")
        NSApp.terminate(nil)
    }
}

// --- Custom Capture UI ---

class CaptureView: NSView {
    var startPoint: NSPoint?
    var endPoint: NSPoint?
    var onCapture: ((CGRect) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        endPoint = startPoint
    }

    override func mouseDragged(with event: NSEvent) {
        endPoint = event.locationInWindow
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint = startPoint, let endPoint = endPoint else { return }
        
        let captureRect = CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(startPoint.x - endPoint.x),
            height: abs(startPoint.y - endPoint.y)
        )
        
        if captureRect.width > 1 && captureRect.height > 1 {
            onCapture?(captureRect)
        }
    }
}

// --- App Delegate ---

class AppDelegate: NSObject, NSApplicationDelegate {
    var captureWindows: [NSWindow] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Argument parsing
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            let parser = ArgumentParser(usage: "<options>", overview: "macOCR")
            if bigSur {
                let languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set Language")
                let parsedArguments = try parser.parse(arguments)
                if let language = parsedArguments.get(languageOption), !language.isEmpty {
                    recognitionLanguages.insert(language, at: 0)
                }
            }
        } catch {
            print("Argument parsing error: \(error)")
            NSApp.terminate(nil)
        }
        
        showCaptureUI()
    }

    func showCaptureUI() {
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            let contentView = CaptureView(frame: NSRect(origin: .zero, size: screenFrame.size))

            contentView.onCapture = { [weak self] rect in
                let windowOrigin = screenFrame.origin
                let globalRect = rect.offsetBy(dx: windowOrigin.x, dy: windowOrigin.y)
                self?.captureScreen(rect: globalRect)
            }

            let window = NSWindow(
                contentRect: screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            
            window.backgroundColor = NSColor.black.withAlphaComponent(0.01)
            window.isOpaque = false
            window.level = .mainMenu + 1
            window.contentView = contentView
            window.makeKeyAndOrderFront(nil)
            
            captureWindows.append(window)
        }
        captureWindows.first?.contentView?.becomeFirstResponder()
    }

    func captureScreen(rect: CGRect) {
        captureWindows.forEach { $0.orderOut(nil) }
        captureWindows.removeAll()
        
        guard let mainScreen = NSScreen.main else {
            print("Error: Could not get main screen.")
            NSApp.terminate(nil)
            return
        }
        let mainScreenHeight = mainScreen.frame.height
        let flippedY = mainScreenHeight - (rect.origin.y + rect.height)

        let rectString = "\(Int(rect.origin.x)),\(Int(flippedY)),\(Int(rect.width)),\(Int(rect.height))"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-x", "-r", "-R", rectString, inputURL.path]
            task.launch()
            task.waitUntilExit()
            
            let fileManager = FileManager.default
            if let attributes = try? fileManager.attributesOfItem(atPath: inputURL.path),
               let fileSize = attributes[.size] as? NSNumber,
               fileSize.intValue > 0 {
                print("Screenshot saved successfully, size: \(fileSize.intValue) bytes.")
                detectText(from: inputURL)
            } else {
                print("Screenshot file is missing or empty.")
                NSApp.terminate(nil)
            }
        }
    }
}

// --- Main App Execution ---

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
