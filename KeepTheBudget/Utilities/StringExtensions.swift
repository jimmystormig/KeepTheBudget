//
//  StringExtensions.swift
//  KeepTheBudget
//
//  String extensions for debugging
//

import Foundation

extension String {
    func appendToFile(path: String) throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            try self.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            fileHandle.seekToEndOfFile()
            if let data = self.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
    }
}
