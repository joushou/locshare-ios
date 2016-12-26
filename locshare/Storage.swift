//
//  Storage.swift
//  locshare
//
//  Created by Kenny Levinsen on 25/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

class ChainKeyEntry {
    private let MAX_MESSAGE_KEYS = 1024

    var senderRatchetKey : ECPublicKey
    var chainKey : ChainKey
    var messageKeyList = [MessageKey]()

    init(senderRatchetKey: ECPublicKey, chainKey: ChainKey) {
        self.senderRatchetKey = senderRatchetKey
        self.chainKey = chainKey
    }

    func popMessageKey(counter: Int) -> MessageKey? {
        for (index, value) in messageKeyList.enumerated() {
            if value.counter == counter {
                messageKeyList.remove(at: index)
                return value
            }
        }

        return nil
    }

    func addMessageKey(messageKey: MessageKey) {
        messageKeyList.append(messageKey)
        if (messageKeyList.count > MAX_MESSAGE_KEYS) {
            messageKeyList.remove(at: 0)
        }
    }
}

class InMemorySessionStore : SessionStore {
    private let MAX_RECEIVER_CHAINS = 5

    var theirIdentity : ECPublicKey?
    var theirTemporaryKeyID : Int = 0
    var theirOneTimeKeyID : Int = 0
    var ourBaseKey : ECKeyPair?
    var hasUnacknowledgedPreKey : Bool = false
    var senderRatchetKey : ECKeyPair?
    var senderChainKey : ChainKey?
    var rootKey : RootKey?
    var previousCounter : Int = 0
    var ourOneTimeKey : ECKeyPair?
    var receiverChain = [ChainKeyEntry]()

    func setTheirIdentity(_ identity: ECPublicKey?) {
        self.theirIdentity = identity
    }

    func getTheirIdentity() -> ECPublicKey? {
        return self.theirIdentity
    }

    func setTheirTemporaryKeyID(_ temporaryKeyID: Int) {
        self.theirTemporaryKeyID = temporaryKeyID
    }

    func getTheirTemporaryKeyID() -> Int {
        return self.theirTemporaryKeyID
    }

    func setTheirOneTimeKeyID(_ oneTimeKeyID: Int) {
        self.theirOneTimeKeyID = oneTimeKeyID
    }

    func getTheirOneTimeKeyID() -> Int {
        return self.theirOneTimeKeyID
    }

    func setOurBaseKey(_ baseKey: ECKeyPair?) {
        self.ourBaseKey = baseKey
    }

    func getOurBaseKey() -> ECKeyPair? {
        return self.ourBaseKey
    }

    func setHasUnacknowledgedPreKey(_ unacknowledgePreKey: Bool) {
        self.hasUnacknowledgedPreKey = unacknowledgePreKey
    }

    func getHasUnacknowledgedPreKey() -> Bool {
        return self.hasUnacknowledgedPreKey
    }

    func getReceiverChainKeyEntry(senderEphemeral: ECPublicKey) -> ChainKeyEntry? {
        for value in receiverChain {
            if value.senderRatchetKey.publicKey.elementsEqual(senderEphemeral.publicKey) {
                return value
            }
        }

        return nil
    }

    func setReceiverChain(chainKey: ChainKey, senderEphemeral: ECPublicKey) {
        if let entry = getReceiverChainKeyEntry(senderEphemeral: senderEphemeral) {
            entry.chainKey = chainKey
            return
        }

        let entry = ChainKeyEntry(senderRatchetKey: senderEphemeral, chainKey: chainKey)
        receiverChain.append(entry)
        if (receiverChain.count > MAX_RECEIVER_CHAINS) {
            receiverChain.remove(at: 0)
        }
    }

    func getReceiverChainKey(senderEphemeral: ECPublicKey) -> ChainKey? {
        if let entry = getReceiverChainKeyEntry(senderEphemeral: senderEphemeral) {
            return entry.chainKey
        }

        return nil
    }

    func setMessageKey(messageKey: MessageKey, senderEphemeral: ECPublicKey) {
        if let entry = getReceiverChainKeyEntry(senderEphemeral: senderEphemeral) {
            entry.addMessageKey(messageKey: messageKey)
        }
    }

    func popMessageKey(counter: Int, senderEphemeral: ECPublicKey) -> MessageKey? {
        if let entry = getReceiverChainKeyEntry(senderEphemeral: senderEphemeral) {
            return entry.popMessageKey(counter: counter)
        }

        return nil
    }

    func setSenderRatchetKey(_ senderRatchetKey: ECKeyPair?) {
        self.senderRatchetKey = senderRatchetKey
    }

    func getSenderRatchetKey() -> ECKeyPair? {
        return self.senderRatchetKey
    }

    func setSenderChainKey(_ senderChainKey: ChainKey?) {
        self.senderChainKey = senderChainKey
    }

    func getSenderChainKey() -> ChainKey? {
        return self.senderChainKey
    }

    func setRootKey(_ rootKey: RootKey?) {
        self.rootKey = rootKey
    }

    func getRootKey() -> RootKey? {
        return self.rootKey
    }

    func setPreviousCounter(_ previousCounter: Int) {
        self.previousCounter = previousCounter
    }

    func getPreviousCounter() -> Int {
        return self.previousCounter
    }

    func setOurOneTimeKey(_ oneTimeKey: ECKeyPair?) {
        self.ourOneTimeKey = oneTimeKey
    }

    func getOurOneTimeKey() -> ECKeyPair? {
        return self.ourOneTimeKey
    }
}

var GlobalPrivateStore = InMemoryPrivateStore()

class InMemoryPrivateStore : PrivateStore {
    var ourIdentity : ECKeyPair?
    var ourOneTimeKeys = [Int:ECKeyPair]()
    var ourTemporaryKeys = [Int:ECKeyPair]()

    func setOurIdentity(_ identity: ECKeyPair?) {
        ourIdentity = identity
    }

    func getOurIdentity() -> ECKeyPair? {
        return ourIdentity
    }

    func getOneTimeKey(_ oneTimeKeyID: Int) -> ECKeyPair? {
        return ourOneTimeKeys[oneTimeKeyID]
    }

    func removeOneTimeKey(_ oneTimeKeyID: Int) {
        ourOneTimeKeys.removeValue(forKey: oneTimeKeyID)
    }

    func setOneTimeKey(_ oneTimeKeyID: Int, key: ECKeyPair) {
        ourOneTimeKeys[oneTimeKeyID] = key
    }

    func getTemporaryKey(_ temporaryKeyID: Int) -> ECKeyPair? {
        return ourTemporaryKeys[temporaryKeyID]
    }

    func removeTemporaryKey(_ temporaryKeyID: Int) {
        ourTemporaryKeys.removeValue(forKey: temporaryKeyID)
    }

    func setTemporaryKey(_ temporaryKeyID: Int, key: ECKeyPair) {
        ourTemporaryKeys[temporaryKeyID] = key
    }
}
