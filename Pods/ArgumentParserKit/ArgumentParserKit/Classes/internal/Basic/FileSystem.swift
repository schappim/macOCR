/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

enum FileSystemError: Swift.Error {
    /// Access to the path is denied.
    ///
    /// This is used when an operation cannot be completed because a component of
    /// the path cannot be accessed.
    ///
    /// Used in situations that correspond to the POSIX EACCES error code.
    case invalidAccess

    /// Invalid encoding
    ///
    /// This is used when an operation cannot be completed because a path could
    /// not be decoded correctly.
    case invalidEncoding

    /// IO Error encoding
    ///
    /// This is used when an operation cannot be completed due to an otherwise
    /// unspecified IO error.
    case ioError

    /// Is a directory
    ///
    /// This is used when an operation cannot be completed because a component
    /// of the path which was expected to be a file was not.
    ///
    /// Used in situations that correspond to the POSIX EISDIR error code.
    case isDirectory

    /// No such path exists.
    ///
    /// This is used when a path specified does not exist, but it was expected
    /// to.
    ///
    /// Used in situations that correspond to the POSIX ENOENT error code.
    case noEntry

    /// Not a directory
    ///
    /// This is used when an operation cannot be completed because a component
    /// of the path which was expected to be a directory was not.
    ///
    /// Used in situations that correspond to the POSIX ENOTDIR error code.
    case notDirectory

    /// Unsupported operation
    ///
    /// This is used when an operation is not supported by the concrete file
    /// system implementation.
    case unsupported

    /// An unspecific operating system error.
    case unknownOSError
}

extension FileSystemError {
    init(errno: Int32) {
        switch errno {
        case EACCES:
            self = .invalidAccess
        case EISDIR:
            self = .isDirectory
        case ENOENT:
            self = .noEntry
        case ENOTDIR:
            self = .notDirectory
        default:
            self = .unknownOSError
        }
    }
}

/// Defines the file modes.
enum FileMode {

    enum Option: Int {
        case recursive
        case onlyFiles
    }

    case userUnWritable
    case userWritable

    var cliArgument: String {
        switch self {
        case .userUnWritable:
            return "u-w"
        case .userWritable:
            return "u+w"
        }
    }
}

/// Abstracted access to file system operations.
///
/// This protocol is used to allow most of the codebase to interact with a
/// natural filesystem interface, while still allowing clients to transparently
/// substitute a virtual file system or redirect file system operations.
///
/// NOTE: All of these APIs are synchronous and can block.
//
// FIXME: Design an asynchronous story?
protocol FileSystem: class {
    /// Check whether the given path exists and is accessible.
    func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool

    /// Check whether the given path is accessible and a directory.
    func isDirectory(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is accessible and a file.
    func isFile(_ path: AbsolutePath) -> Bool

    /// Check whether the given path is accessible and is a symbolic link.
    func isSymlink(_ path: AbsolutePath) -> Bool

    /// Get the current working directory (similar to `getcwd(3)`), which can be
    /// different for different (virtualized) implementations of a FileSystem.
    /// The current working directory can be empty if e.g. the directory became
    /// unavailable while the current process was still working in it.
    /// This follows the POSIX `getcwd(3)` semantics.
    var currentWorkingDirectory: AbsolutePath? { get }
}

/// Convenience implementations (default arguments aren't permitted in protocol
/// methods).
extension FileSystem {
    /// exists override with default value.
    func exists(_ path: AbsolutePath) -> Bool {
        return exists(path, followSymlink: true)
    }
}

/// Concrete FileSystem implementation which communicates with the local file system.
private class LocalFileSystem: FileSystem {
    func exists(_ path: AbsolutePath, followSymlink: Bool) -> Bool {
        return exists(path, followSymlink: followSymlink)
    }

    func isDirectory(_ path: AbsolutePath) -> Bool {
        return isDirectory(path)
    }

    func isFile(_ path: AbsolutePath) -> Bool {
        return isFile(path)
    }

    func isSymlink(_ path: AbsolutePath) -> Bool {
        return isSymlink(path)
    }

    var currentWorkingDirectory: AbsolutePath? {
        let cwdStr = FileManager.default.currentDirectoryPath
        return try? AbsolutePath(validating: cwdStr)
    }
}

/// access to the local FS proxy.
var localFileSystem: FileSystem = LocalFileSystem()
