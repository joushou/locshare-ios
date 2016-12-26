//
//  Message.swift
//  locshare
//
//  Created by Kenny Levinsen on 20/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

enum MessageError: Error {
    case invalidType
    case invalidVersion
    case invalidIdentity
    case invalidOneTimeKey
    case invalidTemporaryKey
    case invalidMac
    case noKeysAvailable
}

class PreKeyMessage: CustomStringConvertible {
    static let MESSAGE_TYPE = UInt8(2)
    static let MESSAGE_VERSION = UInt8(1)

    var oneTimeKeyID: Int
    var temporaryKeyID: Int
    var baseKey: ECPublicKey
    var identityKey: ECPublicKey
    var message: Message
    var serialized: Data

    var description : String {
        return "PreKeyMessage(oneTimeKeyID: \(oneTimeKeyID), temporaryKeyID: \(temporaryKeyID), baseKey: \(baseKey), identityKey: \(identityKey), message: \(message))"
    }

    init(oneTimeKeyID: Int, temporaryKeyID: Int, baseKey: ECPublicKey, identityKey: ECPublicKey, message: Message, serialized: Data) {
        self.oneTimeKeyID = oneTimeKeyID
        self.temporaryKeyID = temporaryKeyID
        self.baseKey = baseKey
        self.identityKey = identityKey
        self.message = message
        self.serialized = serialized
    }

    static func deserialize(serialized: Data) throws -> PreKeyMessage {
        let messageType = binarytobyte(serialized, index: 0)
        if messageType != MESSAGE_TYPE {
            throw MessageError.invalidType
        }

        let messageVersion = binarytobyte(serialized, index: 1)
        if messageVersion != MESSAGE_VERSION {
            throw MessageError.invalidVersion
        }

        let oneTimeKeyID = binarytotype(serialized.subdata(in: 2..<6), Int32.self).bigEndian
        let temporaryKeyID = binarytotype(serialized.subdata(in: 6..<10), Int32.self).bigEndian

        let baseKey = ECPublicKey(publicKey: serialized.subdata(in: 10..<42))
        let identityKey = ECPublicKey(publicKey: serialized.subdata(in: 42..<74))
        let message = try Message.deserialize(serialized: serialized.subdata(in: 74..<serialized.count))

        return PreKeyMessage(oneTimeKeyID: Int(oneTimeKeyID), temporaryKeyID: Int(temporaryKeyID), baseKey: baseKey, identityKey: identityKey, message: message, serialized: serialized)
    }

    static func create(preKeyID: Int, signedPreKeyID: Int, baseKey: ECPublicKey, identityKey: ECPublicKey, message: Message) -> PreKeyMessage {
        var buf = Data(bytes: [MESSAGE_TYPE, MESSAGE_VERSION])
        buf.append(typetobinary(Int32(preKeyID).bigEndian))
        buf.append(typetobinary(Int32(signedPreKeyID).bigEndian))
        buf.append(baseKey.publicKey)
        buf.append(identityKey.publicKey)
        buf.append(message.serialized)

        return PreKeyMessage(oneTimeKeyID: preKeyID, temporaryKeyID: signedPreKeyID, baseKey: baseKey, identityKey: identityKey, message: message, serialized: buf)
    }

    static func isPreKeyMessage(serialized: Data) -> Bool {
        return binarytobyte(serialized, index: 0) == MESSAGE_TYPE
    }
}

class Message: CustomStringConvertible {
    static let MESSAGE_TYPE = UInt8(1)
    static let MESSAGE_VERSION = UInt8(1)
    static let MAC_LENGTH = 8
    static let MESSAGE_OVERHEAD = 1 + 1 + 32 + 4 + 4 + MAC_LENGTH

    var senderRatchetKey: ECPublicKey
    var counter: Int
    var previousCounter: Int
    var cipherText: Data
    var mac: Data
    var serialized: Data

    var description : String {
        return "Message(senderRatchetKey: \(senderRatchetKey), counter: \(counter), previousCounter: \(previousCounter), cipherText: \(cipherText.hexEncodedString), mac: \(mac.hexEncodedString))"
    }

    init(senderRatchetKey: ECPublicKey, counter: Int, previousCounter: Int, cipherText: Data, mac: Data, serialized: Data) {
        self.senderRatchetKey = senderRatchetKey
        self.counter = counter
        self.previousCounter = previousCounter
        self.cipherText = cipherText
        self.mac = mac
        self.serialized = serialized
    }

    static func deserialize(serialized: Data) throws -> Message {
        let messageType = binarytobyte(serialized, index: 0)
        if messageType != MESSAGE_TYPE {
            throw MessageError.invalidType
        }

        let messageVersion = binarytobyte(serialized, index: 1)
        if messageVersion != MESSAGE_VERSION {
            throw MessageError.invalidVersion
        }

        let senderRatchetKey = ECPublicKey(publicKey: serialized.subdata(in: 2..<34))
        let counter = binarytotype(serialized.subdata(in: 34..<38), Int32.self).bigEndian
        let previousCounter = binarytotype(serialized.subdata(in: 38..<42), Int32.self).bigEndian
        let cipherText = serialized.subdata(in: 42..<(serialized.count-MAC_LENGTH))
        let mac = serialized.subdata(in: serialized.count-MAC_LENGTH..<serialized.count)

        return Message(senderRatchetKey: senderRatchetKey, counter: Int(counter), previousCounter: Int(previousCounter), cipherText: cipherText, mac: mac, serialized: serialized)
    }

    static func create(macKey: Data, senderRatchetKey: ECPublicKey, counter: Int, previousCounter: Int, cipherText: Data, senderIdentity: ECPublicKey, receiverIdentity: ECPublicKey) -> Message {
        var buf = Data(bytes: [MESSAGE_TYPE, MESSAGE_VERSION])
        buf.append(senderRatchetKey.publicKey)
        buf.append(typetobinary(Int32(counter).bigEndian))
        buf.append(typetobinary(Int32(previousCounter).bigEndian))
        buf.append(cipherText)

        let mac = calculateMac(macKey: macKey, senderIdentity: senderIdentity, receiverIdentity: receiverIdentity, payload: buf)
        buf.append(mac)

        return Message(senderRatchetKey: senderRatchetKey, counter: counter, previousCounter: previousCounter, cipherText: cipherText, mac: mac, serialized: buf)
    }

    func verifyMac(macKey: Data, senderIdentity: ECPublicKey, receiverIdentity: ECPublicKey) -> Bool {
        let payload = serialized.subdata(in: 0..<(serialized.count-Message.MAC_LENGTH))
        return mac.elementsEqual(Message.calculateMac(macKey: macKey, senderIdentity: senderIdentity, receiverIdentity: receiverIdentity, payload: payload))
    }

    static func calculateMac(macKey: Data, senderIdentity: ECPublicKey, receiverIdentity: ECPublicKey, payload: Data) -> Data {
        var buf = Data()
        buf.append(senderIdentity.publicKey)
        buf.append(receiverIdentity.publicKey)
        buf.append(payload)
        return hmac(key: macKey, data: buf).subdata(in: 0..<MAC_LENGTH)
    }

    static func isMessage(serialized: Data) -> Bool {
        return binarytobyte(serialized, index: 0) == MESSAGE_TYPE
    }
}
