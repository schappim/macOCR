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


var joiner = " "
var bigSur = false;

if #available(macOS 11, *) {
    bigSur = true;
}

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
        return
    }
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

func detectText(fileName : URL) -> [CIFeature]? {
    if let ciImage = CIImage(contentsOf: fileName){
        guard let img = convertCIImageToCGImage(inputImage: ciImage) else { return nil}
      
        let requestHandler = VNImageRequestHandler(cgImage: img)

        // Create a new request to recognize text.
        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        request.recognitionLanguages = recognitionLanguages
       
        
        do {
            // Perform the text-recognition request.
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
}
    return nil
}



let inputURL = URL(fileURLWithPath: "/tmp/ocr.png")
var recognitionLanguages = ["en-US"]

do {
    
    
    let arguments = Array(CommandLine.arguments.dropFirst())

    let parser = ArgumentParser(usage: "<options>", overview: "macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard")
    
    if(bigSur){
        let languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set Language (Supports Big Sur and Above)")
        
        
        let parsedArguments = try parser.parse(arguments)
        let language = parsedArguments.get(languageOption)
        
        if (language ?? "").isEmpty{
            
        }else{
            recognitionLanguages.insert(language!, at: 0)
        }
    }

    let _ = ScreenCapture.captureRegion(destination: "/tmp/ocr.png")

    if let features = detectText(fileName : inputURL), !features.isEmpty{}

} catch {
    // handle parsing error
}

exit(EXIT_SUCCESS)
