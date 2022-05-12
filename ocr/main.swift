//
//  main.swift
//  OCR
//
//  Created by Marcus Schappi on 17/5/21, 11:36 am
//

import Foundation
import CoreImage
import Cocoa
import Vision
import ScreenCapture
import ArgumentParserKit

// MARK: Global varibles

var joiner = " "
var bigSur = false
var recognitionLanguages = ["zh-CN"]

if #available(OSX 11, *) {
    bigSur = true;
}

// MARK: Helper functions

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(inputImage, from: inputImage.extent) else { return nil }
    return cgImage
}

func recognizeTextHandler(request: VNRequest, error: Error?) {
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    
    let recognizedStrings = observations.compactMap { observation in
        // Return the string of the top VNRecognizedText instance.
        return observation.topCandidates(1).first?.string
    }
    
    // Process the recognized strings.
    let joined = recognizedStrings.joined(separator: joiner)
    print(joined)
    
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(joined, forType: .string)
}

func detectText(fileName : URL) {
    guard let ciImage = CIImage(contentsOf: fileName) else { return }
    guard let img = convertCIImageToCGImage(inputImage: ciImage) else { return}

    // Create a new request to recognize text.
    let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
    request.recognitionLanguages = recognitionLanguages
    
    do {
        let requestHandler = VNImageRequestHandler(cgImage: img)
        // Perform the text-recognition request.
        try requestHandler.perform([request])
    } catch {
        print("Unable to perform the requests: \(error).")
    }
}

// MARK: 🉑 Start OCR ...

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let parser = ArgumentParser(usage: "<options>", overview: "macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard")
    
    if (bigSur) {
        let languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set Language (Supports Big Sur and Above)")
        let parsedArguments = try parser.parse(arguments)
        let language = parsedArguments.get(languageOption)
        
        if let language = language, !language.isEmpty {
            recognitionLanguages.insert(language, at: 0)
        }
    }
    
    let inputURL = URL(fileURLWithPath: "/tmp/ocr.png")
    let _ = ScreenCapture.captureRegion(destination: "/tmp/ocr.png")
    detectText(fileName : inputURL)
} catch {
    print(error)
}

exit(EXIT_SUCCESS)
