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


var joiner = "\n"
var bigSur = false;

if #available(OSX 11, *) {
    bigSur = true;
}

// MARK: - Version & distribution

/// Bump this in step with the git tag that ships the release. The release job in
/// .github/workflows/build.yml refuses to publish a tag that disagrees with it.
let ocrVersion = "1.2.0"
let ocrRepositoryURL = "https://github.com/schappim/macOCR"
let ocrReleasesURL = "https://github.com/schappim/macOCR/releases/latest"
let ocrAllReleasesURL = "https://github.com/schappim/macOCR/releases"
let ocrLatestReleaseAPI = "https://api.github.com/repos/schappim/macOCR/releases/latest"
let ocrBrewFormula = "schappim/ocr/ocr"

/// The slice this binary was compiled as.
#if arch(arm64)
let ocrBinaryArch = "arm64"
#else
let ocrBinaryArch = "x86_64"
#endif

/// True when an Intel binary is running under Rosetta on Apple Silicon. The
/// sysctl is missing on Intel Macs and before macOS 11, where the call fails and
/// leaves this false, which is the right answer for both.
let ocrIsTranslated: Bool = {
    #if arch(arm64)
    return false
    #else
    var translated: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0) == 0 else { return false }
    return translated == 1
    #endif
}()

/// The build a user should be downloading, which is the machine's architecture
/// rather than this binary's. Someone hitting Apple's "Intel app" warning needs
/// to be sent to the arm64 build, not handed the Intel one again.
let ocrDownloadArch = ocrIsTranslated ? "arm64" : ocrBinaryArch

func printToStandardError(_ message: String) {
    if let data = (message + "\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

func printVersion() {
    if ocrIsTranslated {
        print("macOCR \(ocrVersion) (\(ocrBinaryArch) running under Rosetta; an arm64 build is available)")
    } else {
        print("macOCR \(ocrVersion) (\(ocrBinaryArch))")
    }
    print(ocrRepositoryURL)
}

func printHelp() {
    // --language is only registered on Big Sur and later, so on older systems it
    // is left out rather than advertised as something the parser would reject.
    var optionLines: [String] = []
    if bigSur {
        optionLines.append("  -l, --language <code>     Set the OCR language, e.g. de-DE")
    }
    optionLines += [
        "      --list-languages      List all supported OCR languages",
        "  -R, --rect <x,y,w,h>      Capture a specific region, skipping the interactive selection",
        "  -i, --input <file>        OCR an existing image file instead of capturing the screen",
        "  -s, --save-image <path>   Save the captured screenshot to <path>",
        "  -v, --version             Print the macOCR version",
        "      --update              Check for a newer version and update via Homebrew",
        "  -h, --help                Show this help",
    ]

    var exampleLines = ["  ocr                       Select a region of the screen and OCR it"]
    if bigSur {
        exampleLines.append("  ocr -l ja-JP              OCR using Japanese")
    }
    exampleLines += [
        "  ocr --list-languages      Show every language code this copy supports",
        "  ocr --rect 100,200,500,300",
        "  ocr -i ~/Desktop/screenshot.png",
        "  ocr -s ~/Desktop/capture.png",
    ]

    var text = """
    macOCR \(ocrVersion) - turn any text on your screen into text on your clipboard.

    USAGE:
      ocr [options]

    OPTIONS:
    \(optionLines.joined(separator: "\n"))

    EXAMPLES:
    \(exampleLines.joined(separator: "\n"))


    """

    if !bigSur {
        text += """
        NOTE:
          Choosing a language needs macOS 11 (Big Sur) or later; this copy recognises en-US only.


        """
    }

    text += """
    UPDATING:
      Homebrew:   brew upgrade \(ocrBrewFormula)
      Manual:     \(ocrReleasesURL)
      Or run:     ocr --update

    HOMEPAGE:
      \(ocrRepositoryURL)
    """

    print(text)
}

// MARK: - Updating

/// The real on-disk location of this binary, with symlinks (such as the ones
/// Homebrew puts in its bin directory) resolved.
func resolvedExecutablePath() -> String {
    let path = Bundle.main.executablePath ?? CommandLine.arguments[0]
    return (path as NSString).resolvingSymlinksInPath
}

/// Homebrew links its binaries out of the Cellar, so a resolved path inside the
/// Cellar is a reliable signal that this copy was installed with `brew`.
func isHomebrewInstall() -> Bool {
    return resolvedExecutablePath().contains("/Cellar/")
}

func homebrewExecutablePath() -> String? {
    var candidates: [String] = []

    // The Cellar path this binary resolved to already names the prefix it was
    // installed under, so prefer that over the environment or a fixed guess.
    let path = resolvedExecutablePath()
    if let cellar = path.range(of: "/Cellar/") {
        candidates.append(path[path.startIndex..<cellar.lowerBound] + "/bin/brew")
    }
    if let prefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] {
        candidates.append("\(prefix)/bin/brew")
    }
    candidates += ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
}

/// Best effort lookup of the newest published release. Returns nil when we are
/// offline, rate limited, or GitHub hands back something unexpected.
func latestReleaseVersion() -> String? {
    guard let url = URL(string: ocrLatestReleaseAPI) else { return nil }

    var request = URLRequest(url: url)
    request.timeoutInterval = 6
    request.setValue("macOCR/\(ocrVersion)", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    var tagName: String? = nil
    let semaphore = DispatchSemaphore(value: 0)

    URLSession.shared.dataTask(with: request) { data, _, _ in
        defer { semaphore.signal() }
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return }
        tagName = tag
    }.resume()

    _ = semaphore.wait(timeout: .now() + 8)
    return tagName
}

/// Compares dotted version strings such as "v1.2.0", "1.10" and "1.2.0-beta1".
/// Returns true when `latest` is newer than `current`. A prerelease sorts below
/// the release with the same numbers, so 1.2.0 beats 1.2.0-beta1.
func isNewerVersion(_ latest: String, than current: String) -> Bool {
    func parse(_ version: String) -> (numbers: [Int], isPrerelease: Bool) {
        var trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
        var isPrerelease = false
        if let dash = trimmed.firstIndex(of: "-") {
            isPrerelease = true
            trimmed = String(trimmed[trimmed.startIndex..<dash])
        }
        return (trimmed.split(separator: ".").map { Int($0) ?? 0 }, isPrerelease)
    }

    let latestVersion = parse(latest)
    let currentVersion = parse(current)

    for index in 0..<max(latestVersion.numbers.count, currentVersion.numbers.count) {
        let l = index < latestVersion.numbers.count ? latestVersion.numbers[index] : 0
        let c = index < currentVersion.numbers.count ? currentVersion.numbers[index] : 0
        if l != c { return l > c }
    }

    return currentVersion.isPrerelease && !latestVersion.isPrerelease
}

func printManualUpdateInstructions() {
    let installPath = resolvedExecutablePath()

    if ocrIsTranslated {
        print("\nThis is the Intel build running under Rosetta. The commands below")
        print("replace it with the native Apple Silicon build.")
    }

    print("""

    Replace this copy with the latest \(ocrDownloadArch) build:

      curl -L -o macOCR-\(ocrDownloadArch).tar.gz \\
        \(ocrReleasesURL)/download/macOCR-\(ocrDownloadArch).tar.gz
      tar xzf macOCR-\(ocrDownloadArch).tar.gz
      sudo mv ocr \(installPath)

    Or switch to Homebrew, which can do this for you from then on:

      sudo rm \(installPath)
      brew install \(ocrBrewFormula)

    All releases: \(ocrAllReleasesURL)
    """)
}

/// Asks Homebrew which version of the formula is installed, e.g. "1.1.0".
/// Returns nil when brew cannot answer.
func homebrewInstalledVersion(brew: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: brew)
    process.arguments = ["list", "--versions", ocrBrewFormula]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
    } catch {
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0,
          let output = String(data: data, encoding: .utf8),
          let line = output.split(separator: "\n").first else { return nil }

    return line.split(separator: " ").last.map(String.init)
}

/// Runs `brew upgrade` for the macOCR formula, inheriting stdout/stderr so the
/// user sees Homebrew's own output. Returns brew's exit status.
func runHomebrewUpgrade(brew: String) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: brew)
    process.arguments = ["upgrade", ocrBrewFormula]

    // Our own output is block buffered when stdout is not a terminal, so flush
    // it before brew starts writing or the two get interleaved out of order.
    fflush(stdout)

    do {
        try process.run()
    } catch {
        printToStandardError("Error: could not run \(brew): \(error.localizedDescription)")
        return EXIT_FAILURE
    }

    process.waitUntilExit()
    return process.terminationStatus
}

func performUpdate() -> Never {
    let installedWithHomebrew = isHomebrewInstall()
    print("macOCR \(ocrVersion) (\(ocrBinaryArch)), installed at \(resolvedExecutablePath())")
    print(installedWithHomebrew ? "Installed via Homebrew." : "Installed manually.")
    if ocrIsTranslated {
        print("Running under Rosetta on Apple Silicon; a native arm64 build is available.")
    }

    let latest = latestReleaseVersion()

    if let latest = latest {
        if isNewerVersion(latest, than: ocrVersion) {
            print("A newer version is available: \(latest)")
        } else {
            if isNewerVersion(ocrVersion, than: latest) {
                print("You are ahead of the latest published release (\(latest)).")
            } else {
                print("You are on the latest version (\(latest)).")
            }
            // A translated Intel build is worth replacing even when it is
            // current, so keep going in that case.
            if !ocrIsTranslated {
                if !installedWithHomebrew {
                    print("Homepage: \(ocrRepositoryURL)")
                }
                exit(EXIT_SUCCESS)
            }
        }
    } else {
        print("Could not check GitHub for the latest release.")
    }

    guard installedWithHomebrew, let brew = homebrewExecutablePath() else {
        printManualUpdateInstructions()
        exit(EXIT_SUCCESS)
    }

    print("\nRunning: brew upgrade \(ocrBrewFormula)\n")
    let status = runHomebrewUpgrade(brew: brew)
    guard status == EXIT_SUCCESS else { exit(status) }

    // brew exits 0 when it has nothing to install, so a formula that has not
    // caught up with the release yet would otherwise look like a successful
    // update that changed nothing.
    if let latest = latest, let installed = homebrewInstalledVersion(brew: brew) {
        if isNewerVersion(latest, than: installed) {
            print("""

            Homebrew still has \(installed); the \(latest) formula is not published yet.
            Grab the binary directly if you need it now: \(ocrReleasesURL)
            """)
        } else {
            print("\nmacOCR is now on \(installed).")
        }
    }

    exit(EXIT_SUCCESS)
}

// MARK: - Early flags
//
// These are handled before the argument parser runs so that they behave the
// same on every macOS version, and so --help can carry the install, update and
// homepage details that ArgumentParserKit's generated usage cannot.

/// Options whose value is the following token. The scan below has to step over
/// those tokens, or `ocr --input --version` would print the version instead of
/// treating "--version" as the file name the parser will complain about.
let ocrValueTakingOptions: Set<String> = [
    "-l", "--language",
    "-R", "--rect",
    "-i", "--input",
    "-s", "--save-image",
]

/// Returns the flag macOCR handles itself, or nil. Only tokens in an option
/// position count, and scanning stops at "--".
func earlyFlag(in arguments: [String]) -> String? {
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]

        if argument == "--" { return nil }

        switch argument {
        case "-h", "-help", "--help": return "--help"
        case "-v", "--version": return "--version"
        case "--update": return "--update"
        default: break
        }

        // The --option=value form carries its value inline, so only the bare
        // form consumes the next token.
        if ocrValueTakingOptions.contains(argument) { index += 1 }
        index += 1
    }
    return nil
}

switch earlyFlag(in: Array(CommandLine.arguments.dropFirst())) {
case "--help":
    printHelp()
    exit(EXIT_SUCCESS)
case "--version":
    printVersion()
    exit(EXIT_SUCCESS)
case "--update":
    performUpdate()
default:
    break
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



var recognitionLanguages = ["en-US"]

do {


    let arguments = Array(CommandLine.arguments.dropFirst())

    let parser = ArgumentParser(usage: "<options>", overview: "macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard")

    let listLanguagesOption = parser.add(option: "--list-languages", kind: Bool.self, usage: "List supported OCR languages")
    let rectOption = parser.add(option: "--rect", shortName: "-R", kind: String.self, usage: "Capture specific region: x,y,width,height (no interactive selection)")
    let inputFileOption = parser.add(option: "--input", shortName: "-i", kind: String.self, usage: "Use image file instead of screen capture")
    let saveImageOption = parser.add(option: "--save-image", shortName: "-s", kind: String.self, usage: "Save captured screenshot to specified path")

    var rectValues: (x: Int, y: Int, w: Int, h: Int)? = nil
    var inputFile: String? = nil
    var saveImagePath: String? = nil

    if(bigSur){
        let languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set Language (Supports Big Sur and Above)")


        let parsedArguments = try parser.parse(arguments)

        // Check if user wants to list languages
        if parsedArguments.get(listLanguagesOption) == true {
            if #available(macOS 11.0, *) {
                let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision2)
                print("Supported languages (accurate):")
                for lang in languages {
                    print("  \(lang)")
                }
            } else {
                print("en-US (language detection requires macOS 11.0+)")
            }
            exit(EXIT_SUCCESS)
        }

        // Parse rect option
        if let rectString = parsedArguments.get(rectOption) {
            let parts = rectString.split(separator: ",").compactMap { Int($0) }
            if parts.count == 4 {
                rectValues = (x: parts[0], y: parts[1], w: parts[2], h: parts[3])
            } else {
                print("Error: --rect requires format x,y,width,height (e.g., --rect 100,100,500,300)")
                exit(EXIT_FAILURE)
            }
        }

        // Parse input file option
        inputFile = parsedArguments.get(inputFileOption)

        // Parse save image option
        saveImagePath = parsedArguments.get(saveImageOption)

        let language = parsedArguments.get(languageOption)

        if (language ?? "").isEmpty{

        }else{
            recognitionLanguages.insert(language!, at: 0)
        }
    } else {
        let parsedArguments = try parser.parse(arguments)
        if parsedArguments.get(listLanguagesOption) == true {
            print("en-US (language detection requires macOS 11.0+)")
            exit(EXIT_SUCCESS)
        }

        // Parse rect option
        if let rectString = parsedArguments.get(rectOption) {
            let parts = rectString.split(separator: ",").compactMap { Int($0) }
            if parts.count == 4 {
                rectValues = (x: parts[0], y: parts[1], w: parts[2], h: parts[3])
            } else {
                print("Error: --rect requires format x,y,width,height (e.g., --rect 100,100,500,300)")
                exit(EXIT_FAILURE)
            }
        }

        // Parse input file option
        inputFile = parsedArguments.get(inputFileOption)

        // Parse save image option
        saveImagePath = parsedArguments.get(saveImageOption)
    }

    // Determine the image to process
    var imageURL: URL

    if let input = inputFile {
        // Use provided image file
        let inputPath = (input as NSString).expandingTildeInPath
        imageURL = URL(fileURLWithPath: inputPath)
        if !FileManager.default.fileExists(atPath: imageURL.path) {
            print("Error: Input file does not exist: \(input)")
            exit(EXIT_FAILURE)
        }
    } else {
        // Capture screen region
        let tempPath = "/tmp/ocr.png"
        if let rect = rectValues {
            let _ = ScreenCapture.captureRect(destination: tempPath, x: rect.x, y: rect.y, width: rect.w, height: rect.h)
        } else {
            let _ = ScreenCapture.captureRegion(destination: tempPath)
        }
        imageURL = URL(fileURLWithPath: tempPath)

        // Save image if requested
        if let savePath = saveImagePath {
            let expandedPath = (savePath as NSString).expandingTildeInPath
            do {
                try FileManager.default.copyItem(atPath: tempPath, toPath: expandedPath)
            } catch {
                print("Warning: Could not save image to \(savePath): \(error.localizedDescription)")
            }
        }
    }

    if let features = detectText(fileName: imageURL), !features.isEmpty{}

} catch {
    printToStandardError("Error: \(error)")
    printToStandardError("Run `ocr --help` for usage.")
    exit(EXIT_FAILURE)
}

exit(EXIT_SUCCESS)
