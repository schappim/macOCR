import Foundation

func captureRegion(destination: URL) -> URL {
    let destinationPath = destination.path as String
    
    let task = Process()
    task.launchPath = "/usr/sbin/screencapture"
    task.arguments = ["-i", "-r", destinationPath]
    task.launch()
    task.waitUntilExit()
    
    return destination
}
