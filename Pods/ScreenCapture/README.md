# ScreenCapture

This framework makes capturing screenshots within OS X easy.

To capture a region of the screen, it makes use of `NSTask` to call `/usr/sbin/screencapture`.

## Carthage

`github "nirix/swift-screencapture"`

## How to use it

An example application can be found in the `Example` directory.

### Screenshots

```swift
import ScreenCapture

// Capture part of the screen
let regionUrl = ScreenCapture.captureRegion("/path/to/save/to.png")

// Capture the entire screen
let screenUrl = ScreenCapture.captureScreen("/path/to/save/to.png")
```

### Record screen

```swift
import ScreenCapture

let recorder = ScreenCapture.recordScreen("/path/to/save/to.mp4")

recorder.start()
...
recorder.stop()

let movieUrl = recorder.destination
```

## License

This framework and it's code is released under the MIT license.
