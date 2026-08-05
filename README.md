# macOCR

macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard.
When you invoke the `ocr` command, a "screen capture" like cursor is shown.
Any text within the bounds will be converted to text.

You could invoke the app using the likes of [Alfred.app](https://www.alfredapp.com/), [LaunchBar](https://obdev.at/products/launchbar/index.html), [Hammerspoon](http://www.hammerspoon.org/), [Quicksilver](https://qsapp.com/), [Raycast](https://raycast.com/) etc.

Examples:
- [macOS Shortcut Workflow](https://www.icloud.com/shortcuts/fa91687e481849d6a27ff873ec71599b)
- [Alfred.app Workflow](https://files.littlebird.com.au/OCR2-ONrTkn.zip)
- [Raycast Script](https://gist.github.com/cheeaun/1405816e5ceb397cbc9028204f82dc98)
- [LaunchBar Action](https://github.com/jsmjsm/macOCR-LaunchBar-Action)

An example Alfred.app workflow is [available here](https://files.littlebird.com.au/OCR2-ONrTkn.zip).

If you're still wondering "how does this work?", I always find the .gif is the best way to clarify things:

![How it works](https://files.littlebird.com.au/Screen-Recording-2021-05-21-13-27-27-FEPQtcuk6FFweb4QEk7Y1mXhsv8B.gif)


## Installation

Install with Homebrew (recommended — it is also how `ocr --update` updates you later):

```
brew install schappim/ocr/ocr
```

Once installed, you can then use the [macOS Shortcut Workflow](https://www.icloud.com/shortcuts/fa91687e481849d6a27ff873ec71599b) (see below for details)

Or download a prebuilt binary from the
[latest release](https://github.com/schappim/macOCR/releases/latest).

Apple Silicon:

```
curl -L -o macOCR-arm64.tar.gz \
  https://github.com/schappim/macOCR/releases/latest/download/macOCR-arm64.tar.gz
tar xzf macOCR-arm64.tar.gz
sudo mv ocr /usr/local/bin/ocr
```

Intel:

```
curl -L -o macOCR-x86_64.tar.gz \
  https://github.com/schappim/macOCR/releases/latest/download/macOCR-x86_64.tar.gz
tar xzf macOCR-x86_64.tar.gz
sudo mv ocr /usr/local/bin/ocr
```

You can also compile the code in this repo and put the binary on your path.


When running the app the first time, you will likely be asked to allow the app access to your screen.

![Enabling access to screen](https://files.littlebird.com.au/Shared-Image-2021-05-20-08-58-38.png)

## Usage

### Basic Usage

Simply run `ocr` to interactively select a region of your screen:

```bash
ocr
```

The recognized text will be printed to stdout and copied to your clipboard.

### Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | | Display available options |
| `--language <code>` | `-l` | Set OCR language (macOS 11+) |
| `--list-languages` | | List all supported OCR languages |
| `--rect <x,y,w,h>` | `-R` | Capture a specific screen region without interactive selection |
| `--input <file>` | `-i` | Use an existing image file instead of screen capture |
| `--save-image <path>` | `-s` | Save the captured screenshot to the specified path |
| `--version` | `-v` | Print the installed macOCR version |
| `--update` | | Check for a newer release and update via Homebrew |

### Examples

**OCR with a specific language:**
```bash
ocr -l zh-Hans          # Simplified Chinese
ocr -l ja-JP            # Japanese
ocr --language de-DE    # German
```

**List supported languages:**
```bash
ocr --list-languages
```

**Capture a specific screen region (for scripting):**
```bash
ocr --rect 100,200,500,300
```

**OCR an existing image file:**
```bash
ocr --input ./screenshot.png
ocr -i ~/Documents/image.jpg
```

**Save the captured screenshot:**
```bash
ocr --save-image ~/Desktop/capture.png
```

**Combine options:**
```bash
# Capture region, save image, and use Chinese OCR
ocr --rect 0,0,800,600 --save-image ~/Desktop/shot.png -l zh-Hans
```

## Updating

Not sure which version you have, or where you got it from? `ocr` will tell you:

```bash
ocr --version     # prints the version, architecture and this repository's URL
ocr --help        # also lists how to update and where macOCR lives
```

To update, run:

```bash
ocr --update
```

This checks GitHub for the latest release and, if macOCR was installed with
Homebrew, hands over to `brew upgrade schappim/ocr/ocr` to do the update. For a
manual install it prints the exact commands to replace the binary where it
actually lives — it does not install anything you did not ask for.

If macOS has told you that macOCR is an Intel app, `--update` notices it is
running under Rosetta and points you at the native Apple Silicon build even when
the version itself is current.

Both flags need macOCR 1.2.0 or later. Older copies have no `--help` at all — if
`ocr --help` prints nothing useful, you have a pre-1.2.0 build and can update
with the Homebrew or curl commands in [Installation](#installation).

All releases are listed at
[github.com/schappim/macOCR/releases](https://github.com/schappim/macOCR/releases).

### Supported Languages

On macOS 11 (Big Sur) and later, the following languages are supported:

- `en-US` - English
- `fr-FR` - French
- `it-IT` - Italian
- `de-DE` - German
- `es-ES` - Spanish
- `pt-BR` - Portuguese
- `zh-Hans` - Simplified Chinese
- `zh-Hant` - Traditional Chinese

Run `ocr --list-languages` to see all available languages on your system.

## Add as Shortcut Workflow (Mac Monterey 12+)
1. Open up [MacOS Shortcuts](https://www.icloud.com/shortcuts/fa91687e481849d6a27ff873ec71599b) available on MacOS 12+.
2. Create new `Shortcut`
3. Add `Run Shell script`
4. Set input to one of these (runs this app):
  - `/opt/homebrew/bin/ocr` (if installed via Homebrew on Apple Silicon)
  - `/usr/local/bin/ocr` (if installed manually or via Homebrew on Intel)
5. Goto `Shortcut Details`

<img width="300px" src="https://user-images.githubusercontent.com/11782590/164676495-3c07a73f-5254-47eb-a4ff-d6a943617954.png" alt="settings" />

7. Set `Pin in menubar` as true

![Kapture 2022-04-22 at 19 09 40](https://user-images.githubusercontent.com/11782590/164675564-e4e03c3c-7065-4083-9978-7fd316251b0e.gif)

## OS Support

This should run on macOS Catalina (10.15) and above. Language selection and extended language support requires macOS Big Sur (11.0) or later.

## Who made this?

macOCR was made by [Marcus Schappi](https://twitter.com/schappim). I create software (and even hardware) for real-world businesses, including:

* **[Little Bird Electronics](https://littlebirdelectronics.com.au/)** — Australia's electronics and STEM store, shipping Australia-wide. We sell [Arduino](https://littlebirdelectronics.com.au/collections/arduino), [Raspberry Pi](https://littlebirdelectronics.com.au/collections/raspberry-pi), [micro:bit](https://littlebirdelectronics.com.au/collections/micro-bit), [STEM and STEAM education kits](https://littlebirdelectronics.com.au/collections/stem-education), [e-textiles](https://littlebirdelectronics.com.au/collections/e-textiles), [robotics](https://littlebirdelectronics.com.au/collections/robotics), [sensors](https://littlebirdelectronics.com.au/collections/sensors) and [electronic components](https://littlebirdelectronics.com.au/collections/components).
* **[Struth.app](https://struth.app/)** — AI runs and grows your trade business. The Struth platform is field service management + CRM + AI.

## Thoughts on Sherlocking?

Apple, please sherlock this software!

## MIT License

Copyright 2021 Marcus Schappi

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
