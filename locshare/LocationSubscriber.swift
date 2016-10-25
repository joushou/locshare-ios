//
//  LocationSubscriber.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/21/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation
import CoreLocation

class LocationSubscriber : NSObject, StreamDelegate {
    var inputStream:InputStream!
    var outputStream:OutputStream!
    var persistentBuffer:Data?

    var notifier : ((String) -> ())?

    init?(ip_address: String, port: Int, notifier: @escaping (String) -> ()) {
        super.init()

        self.inputStream = nil
        self.outputStream = nil
        self.persistentBuffer = nil
        self.notifier = notifier

        self.connect(ip_address: ip_address, port: port)

        if inputStream == nil {
            return nil
        }
    }

    func connect(ip_address: String, port: Int) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(nil, ip_address as CFString!, UInt32(port), &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        inputStream?.delegate = self
        outputStream?.delegate = self

        inputStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)

        inputStream?.open()
        outputStream?.open()
    }

    func close() {
        inputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)

        inputStream?.close()
        outputStream?.close()

        inputStream = nil
        outputStream = nil

        persistentBuffer = nil
    }

    func push(_ string: String, encoding: String.Encoding = String.Encoding.utf8) -> Int {
        if let data = string.data(using: encoding, allowLossyConversion: false) {
            var bytesRemaining = data.count
            var totalBytesWritten = 0

            while bytesRemaining > 0 {
                let bytesWritten = data.withUnsafeBytes {
                    outputStream.write(
                        $0.advanced(by: totalBytesWritten),
                        maxLength: bytesRemaining
                    )
                }
                if bytesWritten < 0 {
                    return -1
                } else if bytesWritten == 0 {
                    return totalBytesWritten
                }

                bytesRemaining -= bytesWritten
                totalBytesWritten += bytesWritten
            }

            return totalBytesWritten
        }

        return -1
    }

    func subscribe(uuid: String) { _ = push("sub " + uuid + "\n") }

    func handleMsg(_ data: Data) {
        var s = String(data: data, encoding: String.Encoding.utf8)
        var parts = s?.characters.split { $0 == " " }.map(String.init)
        if parts?.count != 2 {
            return
        }

        let uuid = parts![0]
        let msg = Data(base64Encoded: parts![1])!

        let user = Users.getUser(uuid: uuid)
        if user != nil {
            let plain_text = decryptWithCurve25519PrivateKey(cipher_text: msg, private_key: user!.localPrivKey)
            let location = CLLocation(marshalledData: plain_text!)
            user!.addLocation(location: location)
            if let notifier = notifier {
                notifier(uuid)
            }
        }

    }

    func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        if stream == inputStream {
            switch eventCode {
            case Stream.Event.endEncountered, Stream.Event.errorOccurred:
                inputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                outputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                inputStream?.close()
                outputStream?.close()
                inputStream = nil
                outputStream = nil
                break;
            case Stream.Event.hasBytesAvailable:
                var buf = Data(count: 4096)
                let len = buf.withUnsafeMutableBytes {
                    inputStream!.read($0, maxLength: 4096)
                }


                var lastNewline = 0
                for i in 0 ..< len {
                    if buf[i] == 0x0A {
                        var d = Data()
                        if persistentBuffer != nil {
                            d.append(persistentBuffer!)
                            persistentBuffer = nil
                        }
                        d.append(buf.subdata(in: 0..<i))
                        lastNewline = i+1
                        handleMsg(d)
                    }
                }

                if lastNewline != len{
                    if persistentBuffer == nil {
                        persistentBuffer = Data()
                    }
                    persistentBuffer!.append(buf.subdata(in: lastNewline..<len))
                }

                break;
            default: break;
            }
        }
    }

}
