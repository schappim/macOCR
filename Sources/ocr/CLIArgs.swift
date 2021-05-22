import ArgumentParser
import Foundation

struct CLIArgs {
    struct ocr: ParsableArguments {

        @Flag(name: [.customShort("c"), .long], help: "Copy OCR text to clipboard.")
        var copy: Bool = false

    }
}
