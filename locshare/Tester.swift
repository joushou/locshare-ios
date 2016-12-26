//
//  Tester.swift
//  locshare
//
//  Created by Kenny Levinsen on 25/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation


class Tester {
    func generatePrivateStore() -> InMemoryPrivateStore {
        let store = InMemoryPrivateStore()
        for i in 0..<100 {
            store.setOneTimeKey(i, key: ECKeyPair.generate())
        }
        store.setTemporaryKey(0, key: ECKeyPair.generate())
        store.setOurIdentity(ECKeyPair.generate())
        return store
    }

    func run() {
        cryptoTest()
        sessionTest()
    }

    func cryptoTest() {
        let keyA = ECKeyPair.generate()
        let keyB = ECKeyPair.generate()

        let res1 = keyA.scalarMult(keyB.asPublicKey())
        let res2 = keyA.scalarMult(keyB.asPublicKey())

        if !res1.elementsEqual(res2) {
            NSLog("two identical scalarMult calls resulted in different results")
            NSLog("\(res1.hexEncodedString), \(res2.hexEncodedString)")
            return
        }

        let res3 = keyB.scalarMult(keyA.asPublicKey())
        if !res1.elementsEqual(res3) {
            NSLog("scalarmult result differed between sides")
            NSLog("Results: \(res1.hexEncodedString), \(res3.hexEncodedString)")
            NSLog("Keys: \(keyA.privateKey.hexEncodedString), \(keyB.privateKey.hexEncodedString)")
            return
        }
    }

    func sessionTest() {
        let alicePrivateStore = generatePrivateStore()
        let bobPrivateStore = generatePrivateStore()

        let theirOneTimeKey = bobPrivateStore.getOneTimeKey(0)!
        let theirTemporaryKey = bobPrivateStore.getTemporaryKey(0)!
        let theirSignedTemporaryKey = ECSignedPublicKey.sign(source: theirTemporaryKey.asPublicKey(), signatureKey: bobPrivateStore.getOurIdentity()!)

        if !theirSignedTemporaryKey.verify(signatureKey: bobPrivateStore.getOurIdentity()!.asPublicKey()) {
            NSLog("signature check failed")
            return
        }

        let input1 = Data(bytes: [1, 2, 3] as [UInt8])
        let aliceSessionStore = InMemorySessionStore()
        let bobSessionStore = InMemorySessionStore()
        let aliceSession = Session(store: aliceSessionStore, privateStore: alicePrivateStore)
        let bobSession = Session(store: bobSessionStore, privateStore: bobPrivateStore)

        aliceSession.setup(theirIdentity: bobPrivateStore.getOurIdentity()!.asPublicKey(), theirTemporaryKey: SignedPreKey(publicKey: theirSignedTemporaryKey, id: 0), theirOneTimeKey: PreKey(publicKey: theirOneTimeKey.asPublicKey(), id: 0))

        var msg1 = aliceSession.encrypt(input1)
        var msg2 = aliceSession.encrypt(input1)
        var msg3 = aliceSession.encrypt(input1)

        var res1 : Data?
        var res2 : Data?
        var res3 : Data?

        let msg4 : Data?
        let msg5 : Data?
        let msg6 : Data?

        do {
            res1 = try bobSession.decrypt(msg1)
            res3 = try bobSession.decrypt(msg3)
            res2 = try bobSession.decrypt(msg2)

            msg4 = bobSession.encrypt(input1)
            msg5 = bobSession.encrypt(input1)
            msg6 = bobSession.encrypt(input1)
        } catch MessageError.invalidMac {
            NSLog("invalid mac")
            return
        } catch MessageError.invalidOneTimeKey {
            NSLog("invalid oneTimeKey")
            return
        } catch MessageError.invalidTemporaryKey {
            NSLog("invalid temporaryKey")
            return
        } catch MessageError.invalidIdentity {
            NSLog("invalid identity")
            return
        } catch MessageError.invalidType {
            NSLog("invalid type")
            return
        } catch MessageError.invalidVersion {
            NSLog("invalid version")
            return
        } catch MessageError.noKeysAvailable {
            NSLog("no keys available")
            return
        } catch {
            NSLog("unknown error")
            return
        }

        if !res1!.elementsEqual(input1) || !res2!.elementsEqual(input1) || !res3!.elementsEqual(input1) {
            NSLog("decrypt failed")
            return
        }

        let res4 : Data?
        let res5 : Data?
        let res6 : Data?

        do {
            res4 = try aliceSession.decrypt(msg4!)
            res6 = try aliceSession.decrypt(msg6!)
            res5 = try aliceSession.decrypt(msg5!)

            msg1 = aliceSession.encrypt(input1)
            msg2 = aliceSession.encrypt(input1)
            msg3 = aliceSession.encrypt(input1)
        } catch MessageError.invalidMac {
            NSLog("invalid mac")
            return
        } catch MessageError.invalidOneTimeKey {
            NSLog("invalid oneTimeKey")
            return
        } catch MessageError.invalidTemporaryKey {
            NSLog("invalid temporaryKey")
            return
        } catch MessageError.invalidIdentity {
            NSLog("invalid identity")
            return
        } catch MessageError.invalidType {
            NSLog("invalid type")
            return
        } catch MessageError.invalidVersion {
            NSLog("invalid version")
            return
        } catch MessageError.noKeysAvailable {
            NSLog("no keys available")
            return
        } catch {
            NSLog("unknown error")
            return
        }

        do {
            res1 = try bobSession.decrypt(msg1)
            res3 = try bobSession.decrypt(msg3)
            res2 = try bobSession.decrypt(msg2)

            // msg4 = bobSession.encrypt(input1)
            // msg5 = bobSession.encrypt(input1)
            // msg6 = bobSession.encrypt(input1)
        } catch MessageError.invalidMac {
            NSLog("invalid mac")
            return
        } catch MessageError.invalidOneTimeKey {
            NSLog("invalid oneTimeKey")
            return
        } catch MessageError.invalidTemporaryKey {
            NSLog("invalid temporaryKey")
            return
        } catch MessageError.invalidIdentity {
            NSLog("invalid identity")
            return
        } catch MessageError.invalidType {
            NSLog("invalid type")
            return
        } catch MessageError.invalidVersion {
            NSLog("invalid version")
            return
        } catch MessageError.noKeysAvailable {
            NSLog("no keys available")
            return
        } catch {
            NSLog("unknown error")
            return
        }

        if !res1!.elementsEqual(input1) || !res2!.elementsEqual(input1) || !res3!.elementsEqual(input1) {
            NSLog("decrypt failed")
            return
        }

        NSLog("test succeeded")
    }
}
