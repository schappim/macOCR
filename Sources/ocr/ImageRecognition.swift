import Foundation
import CoreImage
import Cocoa
import Vision

enum OCRError: Error {
    case invalidImage
    case imageHandlerError(Error)
}

private func recognizeTextHandler(callback: @escaping (String?) -> ()) -> (VNRequest, Error?) -> () {
    { (request: VNRequest, error: Error?) in
        guard let observations = request.results as? [VNRecognizedTextObservation]
        else { return }
        callback(
            observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        )
    }
}

func detectText(imageFile fileName: URL, callback: @escaping (String?) -> ()) -> OCRError? {
    guard let ciImage = CIImage(contentsOf: fileName),
          let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent)
    else { return OCRError.invalidImage }
    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
    let textHandler = recognizeTextHandler(callback: callback)
    let request = VNRecognizeTextRequest(completionHandler: textHandler)
    do {
        try requestHandler.perform([request])
    } catch {
        return .imageHandlerError(error)
    }
    return nil
}
