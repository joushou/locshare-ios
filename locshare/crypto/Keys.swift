//
//  Keys.swift
//  locshare
//
//  Created by Kenny Levinsen on 19/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

func hmac(key: Data, data: Data) -> Data {
    var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
    key.withUnsafeBytes { keyBytes -> Void in
        data.withUnsafeBytes { dataBytes -> Void in
            result.withUnsafeMutableBytes { resultBytes -> Void in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes, key.count, dataBytes, data.count, resultBytes)
            }
        }
    }
    return result
}

struct RootKey {
    var key: Data

    init(derivedSecret: Data) {
        self.key = derivedSecret.subdata(in: 0..<32)
    }

    func createChain(theirRatchetKey: ECPublicKey, ourRatchetKey: ECKeyPair) -> (RootKey, ChainKey) {
        let secret = ourRatchetKey.scalarMult(theirRatchetKey)
        let expansion = HKDF.deriveSecrets(inputKeyMaterial: secret, salt: key, info: "WhisperRatchet".data(using: .utf8)!, outputLength: 64)
        let rk = RootKey(derivedSecret: expansion)
        let ck = ChainKey(derivedSecret: expansion)

        return (rk, ck)
    }
}

struct ChainKey {
    static let MESSAGE_KEY_SEED: Data = Data(bytes: [0x01] as [UInt8])
    static let CHAIN_KEY_SEED: Data = Data(bytes: [0x02] as [UInt8])

    var key: Data
    var index: Int
    var messageKey: MessageKey

    init(key: Data, index: Int) {
        self.key = key
        self.index = index
        self.messageKey = ChainKey.calculateMessageKey(key: key, index: index)
    }

    init(derivedSecret: Data) {
        self.key = derivedSecret.subdata(in: 32..<64)
        self.index = 0
        self.messageKey = ChainKey.calculateMessageKey(key: key, index: 0)
    }

    static func calculateMessageKey(key: Data, index: Int) -> MessageKey {
        let inputKeyMaterial = ChainKey.getBaseMaterial(key: key, seed:ChainKey.MESSAGE_KEY_SEED)
        let keyMaterialBytes = HKDF.deriveSecrets(inputKeyMaterial: inputKeyMaterial, info: "WhisperMessageKeys".data(using: .utf8)!, outputLength: 80)
        let cipherKey = keyMaterialBytes.subdata(in: 0..<32)
        let macKey = keyMaterialBytes.subdata(in: 32..<64)
        let iv = keyMaterialBytes.subdata(in: 64..<80)

        return MessageKey(cipherKey: cipherKey, macKey: macKey, iv: iv, counter: index)
    }

    func nextChainKey() -> ChainKey {
        let nextKey = ChainKey.getBaseMaterial(key:key, seed:ChainKey.CHAIN_KEY_SEED)
        return ChainKey(key: nextKey, index: index+1)
    }

    static func getBaseMaterial(key: Data, seed: Data) -> Data {
        return hmac(key: key, data: seed)
    }
}

struct MessageKey {
    var cipherKey : Data
    var macKey : Data
    var iv : Data
    var counter : Int
}
