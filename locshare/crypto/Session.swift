//
//  Session.swift
//  locshare
//
//  Created by Kenny Levinsen on 19/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

struct AliceSessionParameters {
    var ourIdentity: ECKeyPair
    var ourBaseKey: ECKeyPair
    var theirIdentity: ECPublicKey
    var theirTemporaryKey: ECSignedPublicKey
    var theirOneTimeKey: ECPublicKey

    // var description : String {
    //     return "AliceSessionParameters(ourIdentity: \(ourIdentity.publicKey.hexEncodedString), ourBaseKey: \(ourBaseKey.publicKey.hexEncodedString), theirIdentity: \(theirIdentity.publicKey.hexEncodedString), theirTemporaryKey: \(theirTemporaryKey.publicKey.hexEncodedString), theirOneTimeKey: \(theirOneTimeKey.publicKey.hexEncodedString))"
    // }
}

struct BobSessionParameters {
    var ourIdentity: ECKeyPair
    var ourTemporaryKey: ECKeyPair
    var ourOneTimeKey: ECKeyPair
    var theirIdentity: ECPublicKey
    var theirBaseKey: ECPublicKey

    // var description : String {
    //     return "BobSessionParameters(theirIdentity: \(theirIdentity.publicKey.hexEncodedString), theirBaseKey: \(theirBaseKey.publicKey.hexEncodedString), ourIdentity: \(ourIdentity.publicKey.hexEncodedString), ourTemporaryKey: \(ourTemporaryKey.publicKey.hexEncodedString), ourOneTimeKey: \(ourOneTimeKey.publicKey.hexEncodedString))"
    // }
}

protocol SessionStore {
    func setTheirIdentity(_: ECPublicKey?)
    func getTheirIdentity() -> ECPublicKey?

    func setTheirTemporaryKeyID(_: Int)
    func getTheirTemporaryKeyID() -> Int

    func setTheirOneTimeKeyID(_: Int)
    func getTheirOneTimeKeyID() -> Int

    func setOurBaseKey(_: ECKeyPair?)
    func getOurBaseKey() -> ECKeyPair?

    func setHasUnacknowledgedPreKey(_: Bool)
    func getHasUnacknowledgedPreKey() -> Bool

    func setReceiverChain(chainKey: ChainKey, senderEphemeral: ECPublicKey)
    func getReceiverChainKey(senderEphemeral: ECPublicKey) -> ChainKey?

    func setMessageKey(messageKey: MessageKey, senderEphemeral: ECPublicKey)
    func popMessageKey(counter: Int, senderEphemeral: ECPublicKey) -> MessageKey?

    func setSenderRatchetKey(_: ECKeyPair?)
    func getSenderRatchetKey() -> ECKeyPair?

    func setSenderChainKey(_: ChainKey?)
    func getSenderChainKey() -> ChainKey?

    func setRootKey(_: RootKey?)
    func getRootKey() -> RootKey?

    func setPreviousCounter(_: Int)
    func getPreviousCounter() -> Int

    func setOurOneTimeKey(_: ECKeyPair?)
    func getOurOneTimeKey() -> ECKeyPair?

}

protocol PrivateStore {
    func setOurIdentity(_: ECKeyPair?)
    func getOurIdentity() -> ECKeyPair?

    func getOneTimeKey(_: Int) -> ECKeyPair?
    func removeOneTimeKey(_: Int)

    func getTemporaryKey(_: Int) -> ECKeyPair?
    func removeTemporaryKey(_: Int)
}

class Session {
    var store: SessionStore
    var privateStore: PrivateStore

    init(store: SessionStore, privateStore: PrivateStore) {
        self.store = store
        self.privateStore = privateStore
    }

    func setup(theirIdentity: ECPublicKey, theirTemporaryKey: SignedPreKey, theirOneTimeKey: PreKey) {
        let ourBaseKey = ECKeyPair.generate()

        let p = AliceSessionParameters(ourIdentity: privateStore.getOurIdentity()!,
                                       ourBaseKey: ourBaseKey,
                                       theirIdentity: theirIdentity,
                                       theirTemporaryKey: theirTemporaryKey.publicKey,
                                       theirOneTimeKey: theirOneTimeKey.publicKey)

        store.setTheirIdentity(theirIdentity)
        store.setTheirTemporaryKeyID(theirTemporaryKey.id)
        store.setTheirOneTimeKeyID(theirOneTimeKey.id)
        store.setOurBaseKey(ourBaseKey)
        store.setHasUnacknowledgedPreKey(true)

        initializeSession(p)
    }

    func getChainKey(theirEphemeral: ECPublicKey) -> ChainKey {
        if let chainKey = store.getReceiverChainKey(senderEphemeral: theirEphemeral) {
            return chainKey
        }

        let rootKey = store.getRootKey()!
        let ourEphemeral = store.getSenderRatchetKey()!
        let (receiverRootKey, receiverChainKey) = rootKey.createChain(theirRatchetKey: theirEphemeral, ourRatchetKey: ourEphemeral)
        let ourNewEphemeral = ECKeyPair.generate()
        let (senderRootKey, senderChainKey) = receiverRootKey.createChain(theirRatchetKey: theirEphemeral, ourRatchetKey: ourNewEphemeral)

        store.setReceiverChain(chainKey: receiverChainKey, senderEphemeral: theirEphemeral)
        store.setRootKey(senderRootKey)
        store.setPreviousCounter(max(store.getSenderChainKey()!.index-1, 0))
        store.setSenderRatchetKey(ourNewEphemeral)
        store.setSenderChainKey(senderChainKey)

        return receiverChainKey
    }

    func getMessageKeys(theirEphemeral: ECPublicKey, chainKey: ChainKey, counter: Int) -> MessageKey? {
        if chainKey.index > counter {
            return store.popMessageKey(counter: counter, senderEphemeral: theirEphemeral)
        }

        if counter - chainKey.index > 1024 {
            return nil
        }

        var tempChainKey = chainKey

        while tempChainKey.index < counter {
            let messageKey = tempChainKey.messageKey
            store.setMessageKey(messageKey: messageKey, senderEphemeral: theirEphemeral)
            tempChainKey = tempChainKey.nextChainKey()
        }

        store.setReceiverChain(chainKey: tempChainKey.nextChainKey(), senderEphemeral: theirEphemeral)
        return tempChainKey.messageKey
    }

    func initializeSession(_ p: AliceSessionParameters) {
        let senderRatchet = ECKeyPair.generate()

        var buf = Data()
        buf.append(getDiscontinuityBytes())
        buf.append(p.ourIdentity.scalarMult(p.theirTemporaryKey))
        buf.append(p.ourBaseKey.scalarMult(p.theirIdentity))
        buf.append(p.ourBaseKey.scalarMult(p.theirTemporaryKey))
        buf.append(p.ourBaseKey.scalarMult(p.theirOneTimeKey))

        var (rootKey, chainKey) = deriveKeys(buf)
        store.setReceiverChain(chainKey: chainKey, senderEphemeral: p.theirTemporaryKey)

        (rootKey, chainKey) = rootKey.createChain(theirRatchetKey: p.theirTemporaryKey, ourRatchetKey: senderRatchet)

        store.setSenderRatchetKey(senderRatchet)
        store.setSenderChainKey(chainKey)
        store.setRootKey(rootKey)
    }

    func initializeSession(_ p: BobSessionParameters) {
        var buf = Data()

        buf.append(getDiscontinuityBytes())
        buf.append(p.ourTemporaryKey.scalarMult(p.theirIdentity))
        buf.append(p.ourIdentity.scalarMult(p.theirBaseKey))
        buf.append(p.ourTemporaryKey.scalarMult(p.theirBaseKey))
        buf.append(p.ourOneTimeKey.scalarMult(p.theirBaseKey))

        let (rootKey, chainKey) = deriveKeys(buf)
        store.setTheirIdentity(p.theirIdentity)
        store.setSenderRatchetKey(p.ourTemporaryKey)
        store.setSenderChainKey(chainKey)
        store.setRootKey(rootKey)
    }

    func encrypt(_ message: Data) -> Data {
        let chainKey = store.getSenderChainKey()!
        let key = chainKey.messageKey
        let cipherText = getCipherText(messageKey: key, plainText: message)!

        let msg = Message.create(macKey: key.macKey, senderRatchetKey: store.getSenderRatchetKey()!.asPublicKey(), counter: chainKey.index, previousCounter: store.getPreviousCounter(), cipherText: cipherText, senderIdentity: privateStore.getOurIdentity()!.asPublicKey(), receiverIdentity: store.getTheirIdentity()!)
        store.setSenderChainKey(chainKey.nextChainKey())

        if !store.getHasUnacknowledgedPreKey() {
            return msg.serialized
        }

        let pmsg = PreKeyMessage.create(preKeyID: store.getTheirOneTimeKeyID(), signedPreKeyID: store.getTheirTemporaryKeyID(), baseKey: store.getOurBaseKey()!.asPublicKey(), identityKey: privateStore.getOurIdentity()!.asPublicKey(), message: msg)

        return pmsg.serialized
    }

    func decrypt(_ cipherText: Data) throws -> Data {
        var msg : Message
        if PreKeyMessage.isPreKeyMessage(serialized: cipherText) {
            let pmsg = try PreKeyMessage.deserialize(serialized: cipherText)

            if let theirIdentity = store.getTheirIdentity() {
                if !theirIdentity.publicKey.elementsEqual(pmsg.identityKey.publicKey) {
                    throw MessageError.invalidIdentity
                }
            }

            var oneTimeKey = store.getOurOneTimeKey()
            if oneTimeKey == nil {
                oneTimeKey = privateStore.getOneTimeKey(pmsg.oneTimeKeyID)
                if oneTimeKey == nil {
                    throw MessageError.invalidOneTimeKey
                }
                store.setOurOneTimeKey(oneTimeKey!)
                privateStore.removeOneTimeKey(pmsg.oneTimeKeyID)
            }

            let temporaryKey = privateStore.getTemporaryKey(pmsg.temporaryKeyID)
            if (temporaryKey == nil) {
                throw MessageError.invalidTemporaryKey
            }

            let identity = privateStore.getOurIdentity()!
            let p = BobSessionParameters(ourIdentity: identity, ourTemporaryKey: temporaryKey!, ourOneTimeKey: oneTimeKey!, theirIdentity: pmsg.identityKey, theirBaseKey: pmsg.baseKey)

            initializeSession(p)

            msg = pmsg.message
        } else if Message.isMessage(serialized: cipherText) {
            msg = try Message.deserialize(serialized: cipherText)
            store.setOurOneTimeKey(nil)
        } else {
            throw MessageError.invalidType
        }

        let chainKey = getChainKey(theirEphemeral: msg.senderRatchetKey)
        let key = getMessageKeys(theirEphemeral: msg.senderRatchetKey, chainKey: chainKey, counter: msg.counter)

        if (key == nil) {
            throw MessageError.noKeysAvailable
        }

        if (!msg.verifyMac(macKey: key!.macKey, senderIdentity: store.getTheirIdentity()!, receiverIdentity: privateStore.getOurIdentity()!.asPublicKey())) {
            throw MessageError.invalidMac
        }

        store.setHasUnacknowledgedPreKey(false)
        store.setTheirTemporaryKeyID(0)
        store.setTheirOneTimeKeyID(0)
        store.setOurBaseKey(nil)

        return getPlainText(messageKey: key!, cipherText: msg.cipherText)!
    }

    func getCipherText(messageKey: MessageKey, plainText: Data) -> Data? {
        var bytes : size_t = 0
        var result = Data(count: plainText.count + kCCBlockSizeAES128)
        let error = messageKey.cipherKey.withUnsafeBytes { cipherKeyBytes -> CCCryptorStatus in
            messageKey.iv.withUnsafeBytes { ivBytes -> CCCryptorStatus in
                plainText.withUnsafeBytes { plainTextBytes -> CCCryptorStatus in
                    result.withUnsafeMutableBytes { resultBytes -> CCCryptorStatus in
                        return CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding), cipherKeyBytes, kCCKeySizeAES256, ivBytes, plainTextBytes, plainText.count, resultBytes, result.count, &bytes)
                    }
                }
            }
        }

        if error != CCCryptorStatus(kCCSuccess) {
            return nil
        }

        return result.subdata(in: 0..<bytes)
    }

    func getPlainText(messageKey: MessageKey, cipherText: Data) -> Data? {
        var bytes : size_t = 0
        var result = Data(count: cipherText.count + kCCBlockSizeAES128)
        let error = messageKey.cipherKey.withUnsafeBytes { cipherKeyBytes -> CCCryptorStatus in
            messageKey.iv.withUnsafeBytes { ivBytes -> CCCryptorStatus in
                cipherText.withUnsafeBytes { cipherTextBytes -> CCCryptorStatus in
                    result.withUnsafeMutableBytes { resultBytes -> CCCryptorStatus in
                        return CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding), cipherKeyBytes, kCCKeySizeAES256, ivBytes, cipherTextBytes, cipherText.count, resultBytes, result.count, &bytes)
                    }
                }
            }
        }

        if error != CCCryptorStatus(kCCSuccess) {
            return nil
        }

        return result.subdata(in: 0..<bytes)
    }

    func getDiscontinuityBytes() -> Data {
        var fill = Data(count: 32)
        for i in 0 ..< fill.count {
            fill[i] = 0xFF
        }

        return fill
    }

    func deriveKeys(_ secret: Data) -> (RootKey, ChainKey) {
        let expansion = HKDF.deriveSecrets(inputKeyMaterial: secret, info: "WhisperText".data(using: .utf8)!, outputLength: 64)
        let rk = RootKey(derivedSecret: expansion)
        let ck = ChainKey(derivedSecret: expansion)

        return (rk, ck)
    }
}
