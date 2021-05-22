# macOCR

macOCR is a command line app that runs OCR on text on your secreen.

By default `ocr` prints the copied text to the terminal.
You can also pass the `-c` flag to the `ocr` command to place the text on our clipboard. 

![How it works](https://github.com/adam-zethraeus/macOCR/blob/main/screen-recording.gif?raw=true)

## Installation

```
> git clone git@github.com:adam-zethraeus/macOCR.git
> cd macOCR
> swift build -c release
> .build/release/ocr -h                                                                                      
USAGE: ocr [--copy]

OPTIONS:
  -c, --copy              Copy OCR text to clipboard
  -h, --help              Show help information.


# You can place the binary in a folder in your $PATH
> PATH=$PATH:~/bin
> cp .build/release/ocr ~/bin
```

When running the app the first time, you will be asked to allow the app access to your screen.

Enable it in: `System Preferences > Security & Privacy > Privacy > Screen Recording`. 

## OS Support

The Swift package is enabled for Big Sur / macOS v11.

## MIT License 

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

