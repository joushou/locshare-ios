//
//  EC.swift
//  locshare
//
//  Created by Kenny Levinsen on 19/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

let G = Data(bytes: [9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] as [UInt8])

enum SigningError: Error {
    case failure
}

func crypto_scalar_mult(private_key: Data, base_point: Data) -> (Data) {
    var data = Data(count: 32)

    data.withUnsafeMutableBytes { (mutableBytes : UnsafeMutablePointer<UInt8>)->Void in // I
        private_key.withUnsafeBytes{ (private_key : UnsafePointer<UInt8>)->Void in    // hate
            base_point.withUnsafeBytes{ (base_point : UnsafePointer<UInt8>)->Void in  // Swift 3
                _ = curve25519_donna(mutableBytes,
                                      private_key,
                                      base_point)
            }
        }
    }

    return data
}

func crypto_sign(signatureKey: ECKeyPair, data: Data) throws -> Data {
    var signature = Data(count: 64)
    var rand = Data(count: 64)
    _ = rand.withUnsafeMutableBytes { mutableBytes in
        SecRandomCopyBytes(kSecRandomDefault, rand.count, mutableBytes)
    }

    let key = signatureKey.privateKey
    let res = signature.withUnsafeMutableBytes { (signatureBytes : UnsafeMutablePointer<UInt8>)->Int32 in
        key.withUnsafeBytes { (keyBytes : UnsafePointer<UInt8>)->Int32 in
            data.withUnsafeBytes { (dataBytes : UnsafePointer<UInt8>)->Int32 in
                rand.withUnsafeBytes { (randBytes : UnsafePointer<UInt8>)->Int32 in
                    curve25519_sign(signatureBytes, keyBytes, dataBytes, UInt(data.count), randBytes)
                }
            }
        }
    }

    if res == -1 {
        throw SigningError.failure
    }

    return signature
}

func crypto_verify(signatureKey: ECPublicKey, data: Data, signature: Data) throws -> Bool {
    let key = signatureKey.publicKey
    let res = signature.withUnsafeBytes { (signatureBytes: UnsafePointer<UInt8>)->Int32 in
        key.withUnsafeBytes { (keyBytes : UnsafePointer<UInt8>)->Int32 in
            data.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>)-> Int32 in
                curve25519_verify(signatureBytes, keyBytes, dataBytes, UInt(data.count))
            }
        }
    }

    return res == 0
}

class ECPublicKey: CustomStringConvertible {
    var publicKey: Data

    var description : String {
        return "ECPublicKey(publicKey: \(publicKey.hexEncodedString))"
    }

    init(publicKey: Data) {
        self.publicKey = publicKey
    }
}

class ECKeyPair: CustomStringConvertible {
    var publicKey: Data
    var privateKey: Data

    var description : String {
        return "ECKeyPair(privateKey: \(privateKey.hexEncodedString), publicKey: \(publicKey.hexEncodedString))"
    }

    init(privateKey: Data) {
        self.privateKey = privateKey
        self.publicKey = crypto_scalar_mult(private_key: privateKey, base_point: G)
    }

    init(privateKey: Data, publicKey: Data) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }

    func scalarMult(_ publicKey: ECPublicKey) -> Data {
        return crypto_scalar_mult(private_key: privateKey, base_point: publicKey.publicKey)
    }

    func asPublicKey() -> ECPublicKey {
        return ECPublicKey(publicKey: self.publicKey)
    }

    static func generate() -> ECKeyPair {
        var priv = Data(count: 32)
        _ = priv.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, priv.count, mutableBytes)
        }

        priv[0] &= 248
        priv[31] &= 127
        priv[31] |= 64

        let pub = crypto_scalar_mult(private_key: priv, base_point: G)

        return ECKeyPair(privateKey: priv, publicKey: pub)
    }
}

class ECSignedPublicKey : ECPublicKey {
    var signature: Data

    override var description : String {
        return "ECSignedPublicKey(publicKey: \(publicKey.hexEncodedString), signature: \(signature.hexEncodedString))"
    }

    init(publicKey: Data, signature: Data) {
        self.signature = signature
        super.init(publicKey: publicKey)
    }

    func verify(signatureKey: ECPublicKey) -> Bool {
        return try! crypto_verify(signatureKey: signatureKey, data: publicKey, signature: signature)
    }

    static func sign(source: ECPublicKey, signatureKey: ECKeyPair) -> ECSignedPublicKey {
        let signature = try! crypto_sign(signatureKey: signatureKey, data: source.publicKey)
        return ECSignedPublicKey(publicKey: source.publicKey, signature: signature)
    }
}

struct PreKey {
    var publicKey: ECPublicKey
    var id: Int
}

struct SignedPreKey {
    var publicKey: ECSignedPublicKey
    var id: Int
}
