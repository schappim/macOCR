# macOCR

macOCR is a command line app that enables you to turn any text on your screen into text on your clipboard.
When you envoke the `ocr` command, a "screen capture" like cursor is shown. 
Any text within the bounds will be converted to text. 

You could invoke the app using the likes of [Alfred.app](https://www.alfredapp.com/), [Hammerspoon](http://www.hammerspoon.org/), Quicksilver etc.

If you're still wondering "how does this work ?", I always find the .gif is the best way to clarify things: 

![How it works](https://files.littlebird.com.au/Screen-Recording-2021-05-20-08-42-33-pJWCLojgQFnwt4TVl6pKfizOtuqf.gif)


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



When running the app the first time, you'll be asked to allow the app access to your screen. 

![Enabling access to screen](https://files.littlebird.com.au/Shared-Image-2021-05-20-08-58-38.png)
