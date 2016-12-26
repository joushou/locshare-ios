//
//  HKDF.swift
//  locshare
//
//  Created by Kenny Levinsen on 20/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

class HKDF {
    static func deriveSecrets(inputKeyMaterial: Data, info: Data, outputLength: Int) -> Data {
        let salt = Data(count:32)
        return deriveSecrets(inputKeyMaterial: inputKeyMaterial, salt: salt, info: info, outputLength: outputLength)
    }

    static func deriveSecrets(inputKeyMaterial: Data, salt: Data, info: Data, outputLength: Int) -> Data {
        let prk = extract(salt: salt, inputKeyMaterial: inputKeyMaterial)
        return expand(prk: prk, info: info, outputSize: outputLength)
    }

    static func extract(salt: Data, inputKeyMaterial: Data) -> Data {
        var result = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        salt.withUnsafeBytes { saltBytes -> Void in
            inputKeyMaterial.withUnsafeBytes { inputKeyMaterialBytes -> Void in
                result.withUnsafeMutableBytes { resultBytes -> Void in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), saltBytes, salt.count, inputKeyMaterialBytes, inputKeyMaterial.count, resultBytes)
                }
            }
        }

        return result
    }

    static func expand(prk: Data, info: Data, outputSize: Int) -> Data {
        var result = Data()
        let iterations = Int(ceil(Double(outputSize) / 32))
        var mixin = Data()
        var remainingBytes = outputSize

        for i in 0..<iterations+1 {
            var buf = Data()
            buf.append(mixin)
            buf.append(info)
            buf.append(UInt8(i))

            mixin = hmac(key: prk, data: buf)

            let stepSize = min(remainingBytes, mixin.count)
            result.append(mixin.subdata(in: 0..<stepSize))
            remainingBytes -= stepSize
        }

        return result
    }
}
