//
//  Utils.swift
//  locshare
//
//  Created by Kenny Levinsen on 21/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

func binarytobyte(_ value: Data, index: Int) -> UInt8 {
    let bytes = value.withUnsafeBytes {
        [UInt8](UnsafeBufferPointer(start: $0, count: value.count))
    }

    return bytes[index]
}

func binarytotype <T> (_ value: Data, _: T.Type) -> T {
    let bytes = value.withUnsafeBytes {
        [UInt8](UnsafeBufferPointer(start: $0, count: value.count))
    }

    return binarytotype(bytes, T.self)
}

func binarytotype <T> (_ value: [UInt8], _: T.Type) -> T {
    return value.withUnsafeBufferPointer {
        $0.baseAddress!
            .withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
        }
    }
}

func binarytotype <T> (_ value: ArraySlice<UInt8>, _: T.Type) -> T {
    return value.withUnsafeBufferPointer {
        $0.baseAddress!
            .withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
        }
    }
}

func typetobinary <T> (_ value: T) -> Data {
    var mv : T = value
    return Data(buffer: UnsafeBufferPointer(start: &mv, count: 1))
}

func synced<T>(lock: AnyObject, closure: () -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return closure()
}

extension Data {
    var hexEncodedString : String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
