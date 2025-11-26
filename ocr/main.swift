import Foundation
import Cocoa
import Vision
import ArgumentParserKit

var joiner = " "
var bigSur = false;

if #available(OSX 11, *) {
    bigSur = true;
}

var recognitionLanguages = ["en-US"]
let inputURL = URL(fileURLWithPath: "/tmp/ocr.png")

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
        return cgImage
    }
    return nil
}

func recognizeTextHandler(request: VNRequest, error: Error?) {
    guard let observations =
            request.results as? [VNRecognizedTextObservation] else {
        exit(EXIT_FAILURE)
    }
    let recognizedStrings = observations.compactMap { observation in
        return observation.topCandidates(1).first?.string
    }
    
    let joined = recognizedStrings.joined(separator: joiner)
    print(joined)
    
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(joined, forType: .string)
    
    exit(EXIT_SUCCESS)
}

func detectText(fileName : URL) {
    if let ciImage = CIImage(contentsOf: fileName){
        guard let img = convertCIImageToCGImage(inputImage: ciImage) else {
            exit(EXIT_FAILURE)
        }
      
        let requestHandler = VNImageRequestHandler(cgImage: img)

        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        request.recognitionLanguages = recognitionLanguages
       
        do {
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the requests: \(error).")
            exit(EXIT_FAILURE)
        }
    } else {
        print("Could not load image from \(fileName)")
        exit(EXIT_FAILURE)
    }
}

// Parse arguments
do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let parser = ArgumentParser(usage: "<options>", overview: "macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard")
    
    if(bigSur){
        let languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set Language (Supports Big Sur and Above)")
        let parsedArguments = try parser.parse(arguments)
        if let language = parsedArguments.get(languageOption), !language.isEmpty {
            recognitionLanguages.insert(language, at: 0)
        }
    }
} catch {
    print("Argument parsing error: \(error)")
    exit(EXIT_FAILURE)
}

// Start the screen capture
let task = Process()
task.launchPath = "/usr/sbin/screencapture"
task.arguments = ["-i", "-r", inputURL.path]
task.launch()
task.waitUntilExit()

detectText(fileName: inputURL)

RunLoop.main.run() // Keep the process alive for the Vision request to complete
