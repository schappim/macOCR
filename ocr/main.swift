//
//  main.swift
//  OCR
//
//  Created by Marcus Schappi on 17/5/21, 11:36 am
//

import Foundation
import CoreImage
import CoreGraphics
import ImageIO
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
let ocrVersion = "1.3.0"
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

/// PDF pages are drawn rather than decoded, so macOCR has to pick a resolution.
/// 200dpi is about where Vision stops making mistakes on a scan of ordinary body
/// text, and well short of the sizes where drawing the page costs more than
/// reading it does.
let ocrDefaultPDFDPI = 200

/// The most macOCR will draw one page into. An A0 poster at 200dpi is over sixty
/// megapixels, which is a quarter of a gigabyte of bitmap and past the size Vision
/// makes anything of. A page bigger than this is drawn smaller rather than refused.
let ocrMaximumPagePixels = 30_000_000.0

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
        "  -b, --barcodes            Read only QR codes and barcodes, ignoring any text",
        "      --no-barcodes         Read only text, ignoring any QR codes and barcodes",
        "      --symbologies <list>  Only look for these symbologies, e.g. QR,EAN13",
        "      --list-symbologies    List every barcode symbology this copy can read",
        "      --json                Print results as JSON instead of plain text",
        "  -c, --clipboard           Read the image already on the clipboard",
        "  -i, --input <file>        Read an image or PDF instead of capturing the screen",
        "                            (\"-\" reads it from standard input)",
        "      --pages <list>        Which pages of a PDF to read, e.g. 1,4,7-9",
        "      --dpi <n>             Resolution PDF pages are drawn at (default \(ocrDefaultPDFDPI))",
        "  -R, --rect <x,y,w,h>      Capture a specific region, skipping the interactive selection",
        "  -s, --save-image <path>   Save the captured screenshot to <path>",
        "      --no-copy             Print the result without putting it on the clipboard",
        "  -v, --version             Print the macOCR version",
        "      --update              Check for a newer version and update via Homebrew",
        "  -h, --help                Show this help",
    ]

    var exampleLines = ["  ocr                       Select a region and read the text and codes in it"]
    if bigSur {
        exampleLines.append("  ocr -l ja-JP              OCR using Japanese")
    }
    exampleLines += [
        "  ocr --list-languages      Show every language code this copy supports",
        "  ocr -b                    Read only the QR codes and barcodes in the region",
        "  ocr -b --symbologies QR   Read QR codes only, ignoring other barcodes",
        "  ocr --no-barcodes         Read only the text, as macOCR did before 1.3.0",
        "  ocr --json                Get the text, symbology and position of everything read",
        "  ocr -c                    Read the screenshot you just copied",
        "  ocr -i scan.pdf           Read every page of a PDF",
        "  ocr -i scan.pdf --pages 2-4",
        "  curl -sL example.com/label.png | ocr -i -",
        "  ocr --rect 100,200,500,300",
        "  ocr -i ~/Desktop/screenshot.png",
        "  ocr -s ~/Desktop/capture.png",
    ]

    var text = """
    macOCR \(ocrVersion) - turn any text, QR code or barcode on your screen into
    text on your clipboard.

    By default macOCR reads both: any text in the region, plus the payload of any
    QR code or barcode it finds, in the order they appear on screen. It can read
    the same things out of the clipboard, an image file, a PDF or standard input.

    USAGE:
      ocr [options]

    OPTIONS:
    \(optionLines.joined(separator: "\n"))

    EXAMPLES:
    \(exampleLines.joined(separator: "\n"))

    EXIT STATUS:
      With --barcodes, macOCR exits 1 when it finds no codes, so a script can tell
      "nothing there" from a successful read. The other modes succeed on an empty
      region. Any error exits 1 and explains itself on stderr.


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
    "--symbologies",
    "-R", "--rect",
    "-i", "--input",
    "-s", "--save-image",
    "--pages",
    "--dpi",
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

// MARK: - Decoding

/// One image macOCR is about to read, together with the way up it should be read.
struct ScanImage {
    let image: CGImage
    let orientation: CGImagePropertyOrientation
    /// 1-based page number, set only when the image is a page rendered out of a PDF.
    let page: Int?
}

/// A camera writes the sensor's pixels out unrotated and records which way up it
/// was held in an EXIF tag. Decoding does not apply that tag, so a photo of a
/// receipt taken in portrait arrives on its side and Vision reads little of it.
/// The tag is handed to Vision rather than used to rotate the pixels, which is
/// both cheaper and the coordinate space Vision reports its results in.
func imageOrientation(of source: CGImageSource) -> CGImagePropertyOrientation {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let raw = properties[kCGImagePropertyOrientation] as? UInt32,
          let orientation = CGImagePropertyOrientation(rawValue: raw) else { return .up }
    return orientation
}

func decodeImage(from data: Data) -> ScanImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    return ScanImage(image: image, orientation: imageOrientation(of: source), page: nil)
}

// MARK: - PDFs

/// True when these bytes are a PDF rather than a picture. Reading the header
/// beats trusting a file name: it is the only thing available for --clipboard and
/// for standard input, and it is right about a PDF that someone saved as .png.
func looksLikePDF(_ data: Data) -> Bool {
    return data.starts(with: [0x25, 0x50, 0x44, 0x46]) // "%PDF"
}

/// Parses a page list such as "3", "2-5" or "1,4,7-9" into 1-based page numbers,
/// in the order they were asked for and without repeats.
func parsePageSelection(_ list: String, pageCount: Int) -> [Int] {
    func fail(_ message: String) -> Never {
        printToStandardError("Error: \(message)")
        printToStandardError("--pages takes page numbers and ranges, e.g. --pages 1,4,7-9")
        exit(EXIT_FAILURE)
    }

    var chosen: [Int] = []
    for piece in list.split(separator: ",") {
        let trimmed = piece.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }

        // Empty subsequences are kept so that "-3" and "3-" fail here rather than
        // being read as the page they half look like.
        let bounds = trimmed.split(separator: "-", omittingEmptySubsequences: false)
            .map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard bounds.count <= 2, !bounds.contains(where: { $0 == nil }) else {
            fail("\"\(trimmed)\" is not a page or a range of pages.")
        }

        let first = bounds[0]!
        let last = bounds.count == 2 ? bounds[1]! : first
        guard first >= 1, last >= first else {
            fail("\"\(trimmed)\" is not a page or a range of pages.")
        }
        guard first <= pageCount else {
            fail("page \(first) is past the end of a \(pageCount) page document.")
        }

        // A range that runs off the end is clipped, so `--pages 1-999` means "all
        // of it" rather than an error.
        for page in first...min(last, pageCount) where !chosen.contains(page) {
            chosen.append(page)
        }
    }

    guard !chosen.isEmpty else { fail("--pages needs at least one page, e.g. --pages 1-3") }
    return chosen
}

func renderPDFPage(_ page: CGPDFPage, dpi: Int) -> CGImage? {
    let box = page.getBoxRect(.cropBox)
    guard box.width > 0, box.height > 0 else { return nil }

    // A page whose /Rotate is a quarter turn is drawn on its side, so the bitmap
    // has to be the other way round for it to fit.
    let rotation = ((Int(page.rotationAngle) % 360) + 360) % 360
    let size = (rotation == 90 || rotation == 270)
        ? CGSize(width: box.height, height: box.width)
        : box.size

    // PDF user space is 72 units to the inch, which is what makes this a dpi.
    var scale = Double(dpi) / 72.0
    let pixels = Double(size.width) * Double(size.height) * scale * scale
    if pixels > ocrMaximumPagePixels {
        scale *= (ocrMaximumPagePixels / pixels).squareRoot()
    }

    let width = Int((Double(size.width) * scale).rounded())
    let height = Int((Double(size.height) * scale).rounded())
    guard width > 0, height > 0 else { return nil }

    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }

    // A PDF page is transparent wherever nothing is drawn on it. Without this the
    // text would end up black on black and Vision would find none of it.
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    context.scaleBy(x: scale, y: scale)
    // The drawing transform folds in the page's own rotation and the offset of a
    // crop box that does not start at the origin.
    context.concatenate(page.getDrawingTransform(.cropBox,
                                                 rect: CGRect(origin: .zero, size: size),
                                                 rotate: 0,
                                                 preserveAspectRatio: true))
    context.drawPDFPage(page)
    return context.makeImage()
}

/// Draws each wanted page in turn and hands it straight over, so a long document
/// costs one page of bitmap rather than all of them at once. Collecting them first
/// put a 200 page statement at 3.2GB of resident memory before it printed a line,
/// which is an out-of-memory kill on a small Mac and swap on a large one.
func forEachPDFPage(in data: Data, pages: String?, dpi: Int, _ body: (ScanImage) -> Void) {
    guard let provider = CGDataProvider(data: data as CFData),
          let document = CGPDFDocument(provider) else {
        printToStandardError("Error: that looks like a PDF, but it could not be opened.")
        exit(EXIT_FAILURE)
    }

    guard !document.isEncrypted || document.isUnlocked else {
        printToStandardError("Error: that PDF is password protected, so there is nothing to read.")
        exit(EXIT_FAILURE)
    }

    let pageCount = document.numberOfPages
    guard pageCount > 0 else {
        printToStandardError("Error: that PDF has no pages.")
        exit(EXIT_FAILURE)
    }

    let wanted = pages.map { parsePageSelection($0, pageCount: pageCount) } ?? Array(1...pageCount)

    var drawn = 0
    for number in wanted {
        guard let page = document.page(at: number), let image = renderPDFPage(page, dpi: dpi) else {
            printToStandardError("Warning: page \(number) could not be drawn; skipping it.")
            continue
        }
        drawn += 1
        // The rotation is already in the pixels, so there is no orientation left
        // to tell Vision about.
        body(ScanImage(image: image, orientation: .up, page: number))
    }

    guard drawn > 0 else {
        printToStandardError("Error: none of the pages asked for could be drawn.")
        exit(EXIT_FAILURE)
    }
}

/// Hands over everything macOCR is going to read out of one source: a single
/// image, or one page at a time for a PDF.
func forEachImageToScan(from data: Data,
                        describedAs description: String,
                        pages: String?,
                        dpi: Int?,
                        _ body: (ScanImage) -> Void) {
    if looksLikePDF(data) {
        forEachPDFPage(in: data, pages: pages, dpi: dpi ?? ocrDefaultPDFDPI, body)
        return
    }

    // Neither of these has anything to act on outside a PDF, which is the only
    // thing macOCR draws rather than decodes.
    if pages != nil {
        printToStandardError("Warning: --pages only applies to a PDF; ignoring it.")
    }
    if dpi != nil {
        printToStandardError("Warning: --dpi only applies to a PDF; ignoring it.")
    }

    guard let image = decodeImage(from: data) else {
        printToStandardError("Error: could not read an image from \(description)")
        exit(EXIT_FAILURE)
    }
    body(image)
}

// MARK: - Sources

/// The pasteboard flavours worth trying, best first. An app that copies a picture
/// usually offers several of these at once, and PDF leads because it is the one
/// that is still resolution independent when it gets here.
let ocrClipboardImageTypes: [NSPasteboard.PasteboardType] = [
    NSPasteboard.PasteboardType("com.adobe.pdf"),
    NSPasteboard.PasteboardType("public.png"),
    NSPasteboard.PasteboardType("public.tiff"),
    NSPasteboard.PasteboardType("public.jpeg"),
    NSPasteboard.PasteboardType("public.heic"),
]

/// The picture on the clipboard, or nil when there is not one.
func clipboardData() -> Data? {
    let pasteboard = NSPasteboard.general

    // A file copied in Finder arrives as a URL *and* as a picture of its icon, so
    // the flavour list below would happily read the words off a document icon and
    // report them as the file's contents. Follow the URL first, but only when what
    // it points at is something macOCR can read: a copied .txt has a file URL too,
    // and should fall through to whatever else is on the pasteboard rather than
    // being read as an image and failing.
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
        for url in urls where url.isFileURL {
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            if looksLikePDF(data) || decodeImage(from: data) != nil { return data }
        }
    }

    for type in ocrClipboardImageTypes {
        if let data = pasteboard.data(forType: type), !data.isEmpty { return data }
    }

    return nil
}

/// Everything on standard input. Read in chunks so that piping a file in works
/// the same as a slow producer at the other end of the pipe.
func standardInputData() -> Data {
    var data = Data()
    while true {
        let chunk = FileHandle.standardInput.availableData
        if chunk.isEmpty { break }
        data.append(chunk)
    }
    return data
}

// MARK: - Barcode symbologies

/// Vision spells its symbologies "VNBarcodeSymbologyQR" and friends. The prefix is
/// noise on a command line, so it is dropped on the way out and optional on the way in.
let ocrSymbologyPrefix = "VNBarcodeSymbology"

func symbologyName(_ symbology: VNBarcodeSymbology) -> String {
    let raw = symbology.rawValue
    guard raw.hasPrefix(ocrSymbologyPrefix) else { return raw }
    return String(raw.dropFirst(ocrSymbologyPrefix.count))
}

/// Every symbology this copy of Vision can read. Before Monterey there is nothing
/// to ask, but a fresh request comes configured with all of them, which is the
/// same list by another route.
func supportedSymbologies() -> [VNBarcodeSymbology] {
    let request = VNDetectBarcodesRequest()
    if #available(macOS 12.0, *), let symbologies = try? request.supportedSymbologies() {
        return symbologies
    }
    return request.symbologies
}

/// Case and punctuation are thrown away when matching names, so "QR", "qr",
/// "gs1-databar" and "VNBarcodeSymbologyGS1DataBar" all land on the same symbology.
func symbologyKey(_ name: String) -> String {
    let compact = name.lowercased().filter { $0.isLetter || $0.isNumber }
    let prefix = ocrSymbologyPrefix.lowercased()
    return compact.hasPrefix(prefix) ? String(compact.dropFirst(prefix.count)) : compact
}

/// Turns a `--symbologies QR,EAN13` value into Vision symbologies, exiting with a
/// usable error rather than silently scanning for everything when a name is wrong.
func parseSymbologies(_ list: String) -> [VNBarcodeSymbology] {
    var byKey: [String: VNBarcodeSymbology] = [:]
    for symbology in supportedSymbologies() {
        byKey[symbologyKey(symbology.rawValue)] = symbology
    }

    var chosen: [VNBarcodeSymbology] = []
    for name in list.split(separator: ",") {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        guard let symbology = byKey[symbologyKey(trimmed)] else {
            printToStandardError("Error: \"\(trimmed)\" is not a barcode symbology this Mac can read.")
            printToStandardError("Run `ocr --list-symbologies` to see the ones it can.")
            exit(EXIT_FAILURE)
        }
        if !chosen.contains(symbology) { chosen.append(symbology) }
    }

    if chosen.isEmpty {
        printToStandardError("Error: --symbologies needs at least one symbology, e.g. --symbologies QR,EAN13")
        exit(EXIT_FAILURE)
    }
    return chosen
}

// MARK: - Output

func boundingBoxRecord(_ box: CGRect) -> [String: Any] {
    // Vision works in normalised coordinates with the origin at the bottom left.
    return [
        "x": Double(box.origin.x),
        "y": Double(box.origin.y),
        "width": Double(box.size.width),
        "height": Double(box.size.height),
    ]
}

/// VNConfidence is a Float, and widening one to Double turns 0.95 into
/// 0.949999988079071 in the JSON. Four places is more precision than the number
/// carries anyway, and it reads like something a person would write.
func confidenceValue(_ confidence: VNConfidence) -> Double {
    return (Double(confidence) * 10_000).rounded() / 10_000
}

func jsonString(for records: [[String: Any]]) -> String {
    guard !records.isEmpty else { return "[]" }

    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? JSONSerialization.data(withJSONObject: records, options: options),
          let string = String(data: data, encoding: .utf8) else {
        printToStandardError("Error: could not encode the results as JSON.")
        exit(EXIT_FAILURE)
    }
    return string
}

func copyToClipboard(_ string: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(string, forType: .string)
}

/// The whole point of macOCR is that what it read ends up on the clipboard, so the
/// clipboard gets the plain payloads even when stdout is JSON for a script to parse.
func emit(payloads: [String], records: [[String: Any]], asJSON: Bool, copyResult: Bool) {
    let joined = payloads.joined(separator: joiner)
    print(asJSON ? jsonString(for: records) : joined)

    // Nothing readable came back, so leave the clipboard holding whatever the user
    // already had. A misjudged capture should cost them a second attempt, not
    // whatever they had copied before it.
    if copyResult && !joined.isEmpty { copyToClipboard(joined) }
}

// MARK: - Recognition

/// What macOCR is looking for. Vision can answer both questions about one image in
/// a single pass, so reading codes as well as text costs a request rather than a
/// second run, which is why `both` is the default.
enum ScanMode {
    case text
    case barcodes
    case both
}

/// One thing macOCR read: a line of text, or the payload of a barcode.
struct ScanResult {
    /// nil for a barcode carrying bytes that are not text, which have nothing to
    /// contribute to the clipboard.
    let payload: String?
    let record: [String: Any]

    /// Where this sits in reading order. Text keeps the order Vision returned it
    /// in, and each code is given a fractional order so it slots in between the
    /// lines it sits between on screen.
    let order: Double
    let y: Double
    let x: Double
}

func scanResults(in scanImage: ScanImage, mode: ScanMode, symbologies: [VNBarcodeSymbology]?, asJSON: Bool) -> [ScanResult] {
    // Set on every record from a PDF so that a script reading a document can tell
    // which page a line came off. Absent for anything that has no pages.
    let page = scanImage.page

    var requests: [VNRequest] = []

    let textRequest = VNRecognizeTextRequest()
    textRequest.recognitionLanguages = recognitionLanguages
    if mode != .barcodes { requests.append(textRequest) }

    let barcodeRequest = VNDetectBarcodesRequest()
    if let symbologies = symbologies { barcodeRequest.symbologies = symbologies }
    if mode != .text { requests.append(barcodeRequest) }

    do {
        try VNImageRequestHandler(cgImage: scanImage.image, orientation: scanImage.orientation).perform(requests)
    } catch {
        printToStandardError("Error: unable to read the image: \(error.localizedDescription)")
        exit(EXIT_FAILURE)
    }

    var results: [ScanResult] = []

    let lines = textRequest.results ?? []
    for (index, observation) in lines.enumerated() {
        // Only the top candidate, which is what the clipboard wants.
        guard let candidate = observation.topCandidates(1).first else { continue }
        var record: [String: Any] = [
            "type": "text",
            "text": candidate.string,
            "confidence": confidenceValue(candidate.confidence),
            "boundingBox": boundingBoxRecord(observation.boundingBox),
        ]
        if let page = page { record["page"] = page }

        results.append(ScanResult(
            payload: candidate.string,
            record: record,
            order: Double(index),
            y: Double(observation.boundingBox.midY),
            x: Double(observation.boundingBox.minX)))
    }

    for observation in barcodeRequest.results ?? [] {
        let box = observation.boundingBox

        // Vision returns codes in no particular order, so place each one among the
        // text by where it actually sits: half a step before the first line below
        // it. Vision's origin is the bottom left, so a line with a larger midY is
        // further up the image. Re-sorting the text itself would only make things
        // worse on multi-column layouts, where Vision's own order already reads
        // correctly.
        let linesAbove = lines.filter { $0.boundingBox.midY > box.midY }.count

        var record: [String: Any] = [
            "type": "barcode",
            "symbology": symbologyName(observation.symbology),
            "confidence": confidenceValue(observation.confidence),
            "boundingBox": boundingBoxRecord(box),
        ]
        if let page = page { record["page"] = page }

        let payload = observation.payloadStringValue
        if let payload = payload {
            record["payload"] = payload
        } else {
            // Some codes carry bytes that are not text at all. There is nothing to
            // put on the clipboard for those, so say so rather than drop them
            // silently, and hand the bytes over in JSON where they can be decoded.
            var note = "Note: skipped a \(symbologyName(observation.symbology)) code whose payload is not text"
            if #available(macOS 14.0, *), let data = observation.payloadData {
                record["payloadBase64"] = data.base64EncodedString()
                note += asJSON ? "; it is in the JSON as payloadBase64." : "; run again with --json to get it as base64."
            } else {
                note += "."
            }
            printToStandardError(note)
        }

        results.append(ScanResult(
            payload: payload,
            record: record,
            order: Double(linesAbove) - 0.5,
            y: Double(box.midY),
            x: Double(box.minX)))
    }

    return results.sorted { first, second in
        if first.order != second.order { return first.order < second.order }
        // Centres within a percent of the image height count as the same row, so
        // two codes side by side come out left to right instead of being ordered by
        // whichever sits a hair higher. Rounding to a row is a plain function of y,
        // so this stays a consistent ordering rather than a fuzzy comparison.
        let firstRow = (first.y * 100).rounded(), secondRow = (second.y * 100).rounded()
        if firstRow != secondRow { return firstRow > secondRow }
        return first.x < second.x
    }
}

func report(_ results: [ScanResult], mode: ScanMode, asJSON: Bool, copyResult: Bool) -> Never {
    let payloads = results.compactMap { $0.payload }
    let records = results.map { $0.record }

    // Only --barcodes treats finding nothing as a failure: it is the one mode that
    // exists solely to find codes, so a script can branch on it. The default and
    // --no-barcodes keep succeeding on a blank region, as macOCR always has.
    if mode == .barcodes && records.isEmpty {
        // An empty array still parses, so a script piping into jq gets something
        // it can read; the exit status is what says nothing was found.
        if asJSON { print("[]") }
        printToStandardError("No barcodes found.")
        exit(EXIT_FAILURE)
    }

    emit(payloads: payloads, records: records, asJSON: asJSON, copyResult: copyResult)
    exit(EXIT_SUCCESS)
}


var recognitionLanguages = ["en-US"]

do {


    let arguments = Array(CommandLine.arguments.dropFirst())

    let parser = ArgumentParser(usage: "<options>", overview: "macOCR is a command line app that enables you to turn any text, QR code or barcode on your screen into text on your clipboard. It reads both text and codes unless you narrow it down with --barcodes or --no-barcodes, and reads from the clipboard, an image file, a PDF or standard input as well as from the screen")

    let listLanguagesOption = parser.add(option: "--list-languages", kind: Bool.self, usage: "List supported OCR languages")
    let barcodesOption = parser.add(option: "--barcodes", shortName: "-b", kind: Bool.self, usage: "Read only QR codes and barcodes, ignoring any text")
    let noBarcodesOption = parser.add(option: "--no-barcodes", kind: Bool.self, usage: "Read only text, ignoring any QR codes and barcodes")
    let symbologiesOption = parser.add(option: "--symbologies", kind: String.self, usage: "Only look for these symbologies, e.g. QR,EAN13")
    let listSymbologiesOption = parser.add(option: "--list-symbologies", kind: Bool.self, usage: "List supported barcode symbologies")
    let jsonOption = parser.add(option: "--json", kind: Bool.self, usage: "Print results as JSON instead of plain text")
    let rectOption = parser.add(option: "--rect", shortName: "-R", kind: String.self, usage: "Capture specific region: x,y,width,height (no interactive selection)")
    let inputFileOption = parser.add(option: "--input", shortName: "-i", kind: String.self, usage: "Read an image or PDF instead of capturing the screen (\"-\" for standard input)")
    let saveImageOption = parser.add(option: "--save-image", shortName: "-s", kind: String.self, usage: "Save captured screenshot to specified path")
    let clipboardOption = parser.add(option: "--clipboard", shortName: "-c", kind: Bool.self, usage: "Read the image already on the clipboard instead of capturing the screen")
    let noCopyOption = parser.add(option: "--no-copy", kind: Bool.self, usage: "Print the result without putting it on the clipboard")
    let pagesOption = parser.add(option: "--pages", kind: String.self, usage: "Which pages of a PDF to read, e.g. 1,4,7-9")
    let dpiOption = parser.add(option: "--dpi", kind: Int.self, usage: "Resolution PDF pages are drawn at (default \(ocrDefaultPDFDPI))")

    // --language is only registered on Big Sur and later, where Vision can
    // actually recognise something other than English.
    var languageOption: OptionArgument<String>? = nil
    if bigSur {
        languageOption = parser.add(option: "--language", shortName: "-l", kind: String.self, usage: "Set Language (Supports Big Sur and Above)")
    }

    var rectValues: (x: Int, y: Int, w: Int, h: Int)? = nil
    var inputFile: String? = nil
    var saveImagePath: String? = nil

    let parsedArguments = try parser.parse(arguments)

    // Check if user wants to list languages
    if parsedArguments.get(listLanguagesOption) == true {
        // Ask the same request the OCR path uses rather than a fixed revision.
        // Pinning revision 2 here reported eight languages on Macs whose Vision
        // recognises thirty, so --language accepted codes this flag never listed.
        let request = VNRecognizeTextRequest()

        var languages: [String] = []
        if #available(macOS 12.0, *) {
            languages = (try? request.supportedRecognitionLanguages()) ?? []
        } else if #available(macOS 11.0, *) {
            languages = (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: .accurate, revision: request.revision)) ?? []
        }

        guard !languages.isEmpty else {
            print("en-US (choosing a language requires macOS 11.0 or later)")
            exit(EXIT_SUCCESS)
        }

        print("Supported languages (accurate):")
        for language in languages {
            print("  \(language)")
        }
        exit(EXIT_SUCCESS)
    }

    if parsedArguments.get(listSymbologiesOption) == true {
        print("Supported barcode symbologies:")
        for symbology in supportedSymbologies().map(symbologyName).sorted() {
            print("  \(symbology)")
        }
        exit(EXIT_SUCCESS)
    }

    let outputJSON = parsedArguments.get(jsonOption) == true
    let barcodesOnly = parsedArguments.get(barcodesOption) == true
    let textOnly = parsedArguments.get(noBarcodesOption) == true

    if barcodesOnly && textOnly {
        printToStandardError("Error: --barcodes and --no-barcodes ask for opposite things; pick one.")
        exit(EXIT_FAILURE)
    }

    // Reading both is the default: a screenshot with a QR code in it should give
    // you the QR code without your having to know it was there beforehand.
    let mode: ScanMode = barcodesOnly ? .barcodes : (textOnly ? .text : .both)

    var symbologies: [VNBarcodeSymbology]? = nil
    if let list = parsedArguments.get(symbologiesOption) {
        guard mode != .text else {
            printToStandardError("Error: --symbologies has nothing to narrow when --no-barcodes is set.")
            exit(EXIT_FAILURE)
        }
        symbologies = parseSymbologies(list)
    }

    // Parse rect option
    if let rectString = parsedArguments.get(rectOption) {
        let parts = rectString.split(separator: ",").compactMap { Int($0) }
        if parts.count == 4 {
            rectValues = (x: parts[0], y: parts[1], w: parts[2], h: parts[3])
        } else {
            printToStandardError("Error: --rect requires format x,y,width,height (e.g., --rect 100,100,500,300)")
            exit(EXIT_FAILURE)
        }
    }

    // Parse input file option
    inputFile = parsedArguments.get(inputFileOption)

    let useClipboard = parsedArguments.get(clipboardOption) == true
    let copyResult = parsedArguments.get(noCopyOption) != true

    if useClipboard && inputFile != nil {
        printToStandardError("Error: --clipboard and --input both name what to read; pick one.")
        exit(EXIT_FAILURE)
    }

    let pageSelection = parsedArguments.get(pagesOption)

    // Kept optional so that --dpi can say it has been ignored when the source is
    // not a PDF, which passing the default straight through would hide.
    let requestedDPI = parsedArguments.get(dpiOption)
    if let requestedDPI = requestedDPI, !(36...1200).contains(requestedDPI) {
        printToStandardError("Error: --dpi takes a resolution between 36 and 1200; \(requestedDPI) is outside that.")
        exit(EXIT_FAILURE)
    }

    // Parse save image option
    saveImagePath = parsedArguments.get(saveImageOption)

    if let languageOption = languageOption, let language = parsedArguments.get(languageOption), !language.isEmpty {
        recognitionLanguages.insert(language, at: 0)
    }

    // The capture-only options have nothing to act on once the image is coming
    // from somewhere other than the screen. Saying so beats leaving someone to
    // work out why --rect made no difference.
    let capturingScreen = !useClipboard && inputFile == nil
    if !capturingScreen {
        let elsewhere = useClipboard ? "--clipboard" : "--input"
        if saveImagePath != nil {
            printToStandardError("Warning: --save-image has nothing to save when \(elsewhere) is used; ignoring it.")
        }
        if rectValues != nil {
            printToStandardError("Warning: --rect only applies to a screen capture, which \(elsewhere) replaces; ignoring it.")
        }
    }

    // Determine what to read, and where to say it came from when it will not read.
    let bytes: Data
    let sourceDescription: String
    // Set only when macOCR took the screenshot itself, and so is the one that has
    // to tidy it up afterwards.
    var temporaryCapture: String? = nil

    if useClipboard {
        guard let data = clipboardData() else {
            printToStandardError("Error: there is no image on the clipboard.")
            printToStandardError("Copy a picture, a screenshot or an image file, then run `ocr --clipboard` again.")
            exit(EXIT_FAILURE)
        }
        bytes = data
        sourceDescription = "the clipboard"
    } else if inputFile == "-" {
        // "-" is the usual way to say standard input, so `pdftoppm ... | ocr -i -`
        // and `curl ... | ocr -i -` work without a temporary file.
        bytes = standardInputData()
        guard !bytes.isEmpty else {
            printToStandardError("Error: nothing arrived on standard input.")
            exit(EXIT_FAILURE)
        }
        sourceDescription = "standard input"
    } else if let input = inputFile {
        // Use provided image file
        let inputPath = (input as NSString).expandingTildeInPath
        let imageURL = URL(fileURLWithPath: inputPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: imageURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            printToStandardError("Error: Input file does not exist: \(input)")
            exit(EXIT_FAILURE)
        }
        guard let data = try? Data(contentsOf: imageURL) else {
            printToStandardError("Error: could not read \(imageURL.path)")
            exit(EXIT_FAILURE)
        }
        bytes = data
        sourceDescription = imageURL.path
    } else {
        // The screenshot lands in this user's own temp directory rather than a
        // shared one, under a name carrying this process's id so that two runs at
        // once cannot read each other's capture. Any earlier file of the same name
        // is cleared first, so cancelling the capture leaves nothing behind to be
        // mistaken for a screenshot the user just took.
        let tempPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("macOCR-capture-\(ProcessInfo.processInfo.processIdentifier).png")
        try? FileManager.default.removeItem(atPath: tempPath)

        if let rect = rectValues {
            let _ = ScreenCapture.captureRect(destination: tempPath, x: rect.x, y: rect.y, width: rect.w, height: rect.h)
        } else {
            let _ = ScreenCapture.captureRegion(destination: tempPath)
        }

        guard FileManager.default.fileExists(atPath: tempPath) else {
            printToStandardError("No screenshot was taken; the capture was cancelled.")
            exit(EXIT_FAILURE)
        }

        temporaryCapture = tempPath
        sourceDescription = tempPath

        // Save image if requested
        if let savePath = saveImagePath {
            let expandedPath = (savePath as NSString).expandingTildeInPath
            do {
                try FileManager.default.copyItem(atPath: tempPath, toPath: expandedPath)
            } catch {
                printToStandardError("Warning: Could not save image to \(savePath): \(error.localizedDescription)")
            }
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: tempPath)) else {
            printToStandardError("Error: could not read the screenshot back from \(tempPath)")
            try? FileManager.default.removeItem(atPath: tempPath)
            exit(EXIT_FAILURE)
        }
        bytes = data
    }

    // The screenshot has been read into memory, so the file has done its job.
    // Leaving it on disk would mean every run of macOCR abandoned a copy of
    // whatever was on screen at the time.
    if let path = temporaryCapture {
        try? FileManager.default.removeItem(atPath: path)
    }

    // Each page is sorted into reading order on its own and the pages are then
    // laid end to end, so a document comes out in the order you would read it.
    var results: [ScanResult] = []

    forEachImageToScan(from: bytes,
                       describedAs: sourceDescription,
                       pages: pageSelection,
                       dpi: requestedDPI) { scanImage in
        results += scanResults(in: scanImage, mode: mode, symbologies: symbologies, asJSON: outputJSON)
    }

    report(results, mode: mode, asJSON: outputJSON, copyResult: copyResult)

} catch {
    printToStandardError("Error: \(error)")
    printToStandardError("Run `ocr --help` for usage.")
    exit(EXIT_FAILURE)
}

exit(EXIT_SUCCESS)
