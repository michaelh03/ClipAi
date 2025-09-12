//
//  UUIDV7.swift
//  ClipAI
//
//  Created by Michael Hait on 01/08/2025.
//

import Foundation

public extension UUID {

  static func uuidV7String(withHyphens: Bool = true) -> String {
    let timestamp = Date().timeIntervalSince1970
    let unixTimeMilliseconds = UInt64(timestamp * 1000)
    let timeBytes = unixTimeMilliseconds.bigEndianData.suffix(6) // First 6 bytes for the timestamp

    let randomBytes = Data((0..<10).map { _ in UInt8.random(in: 0...255) })

    var uuidBytes = Data()
    uuidBytes.append(contentsOf: timeBytes)
    uuidBytes.append(contentsOf: randomBytes)

    assert(uuidBytes.count == 16, "UUID must be exactly 16 bytes")

    uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x70

    uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

    let uuidString = uuidBytes.map { String(format: "%02x", $0) }.joined()

    return withHyphens ? uuidString.insertHyphens() : uuidString
  }
}


extension UInt64 {
  internal var bigEndianData: Data {
    var bigEndianValue = self.bigEndian
    return Data(bytes: &bigEndianValue, count: MemoryLayout<UInt64>.size)
  }
}

extension String {
  internal func insertHyphens() -> String {
    let pattern = "(.{8})(.{4})(.{4})(.{4})(.{12})"
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: count)

    return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1-$2-$3-$4-$5") ?? self
  }
}
