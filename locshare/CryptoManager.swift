//
//  CryptoManager.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/20/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

let G = Data(bytes: [9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] as [UInt8])

func scalar_mult(private_key: Data, base_point: Data) -> (Data) {
    var data = Data(count: 32)

    data.withUnsafeMutableBytes { (mutableBytes : UnsafeMutablePointer<UInt8>)->Void in // I
        private_key.withUnsafeBytes{ (private_key : UnsafePointer<UInt8>)->Void in    // hate
            base_point.withUnsafeBytes{ (base_point : UnsafePointer<UInt8>)->Void in  // Swift 3
                _ = crypto_scalarmult(mutableBytes,
                                      private_key,
                                      base_point)
            }
        }
    }

    return data
}

func generate_keypair() -> (Data, Data) {
    var priv = Data(count: 32)
    _ = priv.withUnsafeMutableBytes { mutableBytes in
        SecRandomCopyBytes(kSecRandomDefault, priv.count, mutableBytes)
    }

    priv[0] &= 248
    priv[31] &= 127
    priv[31] |= 64

    let pub = scalar_mult(private_key: priv, base_point: G)

    return (priv, pub)
}

func sha512(data: Data) -> [UInt8] {
    var digest = [UInt8](repeating: 0, count:Int(CC_SHA512_DIGEST_LENGTH))
    data.withUnsafeBytes { bytes -> Void in
        CC_SHA512(bytes, CC_LONG(data.count), &digest)
    }
    return digest
}

func encryptWithCurve25519PublicKey(plain_text: Data, public_key: Data) -> Data? {
    var (r, R) = generate_keypair()
    let S = scalar_mult(private_key: r, base_point: public_key)
    let k_E = sha512(data: S)
    if plain_text.count > k_E.count {
        return nil
    }

    var cipher_text = Data(count: R.count + plain_text.count)
    for i in 0 ..< R.count {
        cipher_text[i] = R[i]
    }

    for i in 0 ..< plain_text.count {
        cipher_text[i+R.count] = plain_text[i] ^ k_E[i]
    }

    return cipher_text
}

func decryptWithCurve25519PrivateKey(cipher_text: Data, private_key: Data) -> Data? {
    var R = Data(count: 32)
    for i in 0 ..< R.count {
        R[i] = cipher_text[i]
    }

    var c = Data(count: cipher_text.count - R.count)
    for i in 0 ..< c.count {
        c[i] = cipher_text[R.count+i]
    }

    let S = scalar_mult(private_key: private_key, base_point: R)

    let k_E = sha512(data: S)
    for i in 0 ..< c.count {
        c[i] ^= k_E[i]
    }

    return c
}
