# ArgumentParserKit

Type-safe and easy way for parsing command line arguments in your macOS command line tools

[![Version](https://img.shields.io/cocoapods/v/ArgumentParserKit.svg?longCache=true&style=flat-square)](http://cocoapods.org/pods/ArgumentParserKit)
[![Swift4](https://img.shields.io/badge/swift4-compatible-orange.svg?longCache=true&style=flat-square)](https://developer.apple.com/swift)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg?longCache=true&style=flat-square)](https://www.apple.com/de/macos)
[![License](https://img.shields.io/badge/license-Apache%20License%20v2.0-lightgrey.svg?longCache=true&style=flat-square)](https://en.wikipedia.org/wiki/Apache_License)

The `ArgumentParser` has out of the box support for the `--help` or `-h` argument. He prints out a beautiful overview of your command line tool usage.

```
👻  Welcome to this awesome Command Line Tool  😊
OVERVIEW: Does amazing things for you

USAGE: CommandLineTool <options>

OPTIONS:
  --name, -n        A name
  --help, -h        Display available options
```

## Example

```swift
do {
    // The first argument is always the executable, drop it
    let arguments = Array(CommandLine.arguments.dropFirst())

    let parser = ArgumentParser(usage: "<options>", overview: "A description")
    let nameOption = parser.add(option: "--name", shortName: "-n", kind: String.self, usage: "A name")

    let parsedArguments = try parser.parse(arguments)
    let name = parsedArguments.get(nameOption)
    print(name)
} catch {
    // handle parsing error
}
```

## How to use

The parsed argument values are only four steps away from you if you use the `ArgumentParser`.

### 1. Create a parser ###

Use the initializer of the `ArgumentParser` class.

```swift
/// Create an argument parser.
///
/// - Parameters:
///   - commandName: If provided, this will be substitued in "usage" line of the generated usage text.
///   Otherwise, first command line argument will be used.
///   - usage: The "usage" line of the generated usage text.
///   - overview: The "overview" line of the generated usage text.
///   - seeAlso: The "see also" line of generated usage text.
///
init(commandName: String? = nil, usage: String, overview: String, seeAlso: String? = nil)
```

### 2. Tell the parser about the arguments to parse ###

Tell the parser which arguments (for the `ArgumentParser` an argument is an instance of `OptionArgument`) your command line tool offers via the `add`-method.

```swift
/// Add an argument to a parser.
///
/// - Parameters:
///   - option: The name of the argument, for example "--name".
///   - shortName: The shortened name of the argument, e.g. "-n".
///   - kind: The concrete type of the argument.
///   - usage: The description of the argument.
///
func add<T: ArgumentKind>(option: String, shortName: String? = nil, kind: T.Type, usage: String? = nil)
```

### 3. Parse arguments passed to your command line tool  ###

Pass your arguments array to the `parse`-method of your parser instance.

```swift
/// Parses the provided array and returns the result.
///
func parse(_ arguments: [String] = []) throws -> Result
```

### 4. Get the values of the passed arguments  ###

After parsing you can access the argument values calling the `get`-method on the `Result` type returned by the `parse`-method of the `ArgumentParser`. Simply pass in the `OptionArgument` returned by the `add`-method of the `ArgumentParser`.

```swift
/// Get an option argument's value from the results.
///
/// Since the options are optional, their result may or may not be present.
///
func get<T>(_ argument: OptionArgument<T>) -> T?
```

## Requirements

Deployment target has to be greater than or equal to 10.10.

## Installation

ArgumentParserKit is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'ArgumentParserKit'
```

## Further resources

Take a look at [Parsing Command Line Arguments using the internal `ArgumentParser` inside of the `Swift Package Manager`](https://www.enekoalonso.com/articles/parsing-command-line-arguments-with-swift-package-manager-argument-parser)

## Author

Apple Inc. and the Swift project authors

## License

ArgumentParserKit is available under the Apache License v2.0 with Runtime Library Exception. See the LICENSE file for more info.
