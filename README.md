# macOCR

macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard.
When you envoke the `ocr` command, a "screen capture" like cursor is shown. 
Any text within the bounds will be converted to text. 

You could invoke the app using the likes of [Alfred.app](https://www.alfredapp.com/), [LaunchBar](https://obdev.at/products/launchbar/index.html), [Hammerspoon](http://www.hammerspoon.org/), [Quicksilver](https://qsapp.com/), [Raycast](https://raycast.com/) etc.

Examples: 
- [Alfred.app Workflow](https://files.littlebird.com.au/OCR.alfredworkflow-aR9crGZYI92tYTa6Q5S1cRGr2rMc.zip)
- [Raycast Script](https://gist.github.com/cheeaun/1405816e5ceb397cbc9028204f82dc98)
- [LaunchBar Aciton](https://github.com/jsmjsm/macOCR-LaunchBar-Action)

An example Alfred.app workflow is [available here](https://files.littlebird.com.au/OCR.alfredworkflow-aR9crGZYI92tYTa6Q5S1cRGr2rMc.zip).

If you're still wondering "how does this work ?", I always find the .gif is the best way to clarify things: 

![How it works](https://files.littlebird.com.au/Screen-Recording-2021-05-21-13-27-27-FEPQtcuk6FFweb4QEk7Y1mXhsv8B.gif)


## Installation

Compile the code in this repo, or download a prebuilt binary ([Apple Silicon](https://files.littlebird.com.au/ocr.zip), [Intel](https://files.littlebird.com.au/ocr-EPiReQzFJ5Xw9wElWMqbiBayYLVp.zip)) and put it on your path.

Apple Silicon Install:

```
curl -O https://files.littlebird.com.au/ocr.zip; 
unzip ocr.zip;
sudo cp ocr /usr/local/bin;
```

Intel Install:

```
curl -O https://files.littlebird.com.au/ocr-EPiReQzFJ5Xw9wElWMqbiBayYLVp.zip; 
unzip ocr-EPiReQzFJ5Xw9wElWMqbiBayYLVp.zip;
sudo cp ocr /usr/local/bin;
```


When running the app the first time, you will likely be asked to allow the app access to your screen.

![Enabling access to screen](https://files.littlebird.com.au/Shared-Image-2021-05-20-08-58-38.png)

## OS Support

This should run on Catalina and above.

## Who made this? 

macOCR was made by [Marcus Schappi](https://twitter.com/schappi). I create software ([and even hardware](https://chickcom.com/hardware)) to automate ecommerce, including: 

* [Chick Commerce](https://chickcom.com/).
* This [free Australia Post app on Shopify](https://apps.shopify.com/auspost-shipping).
* [Script Ninja](https://apps.shopify.com/cockatoo) which enables you to create powerful scripts and tools to automate your Shopify store.

## Thoughts on Sherlocking?

Apple, please sherlock this software!

## MIT License 

Copyright 2021 Marcus Schappi

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

