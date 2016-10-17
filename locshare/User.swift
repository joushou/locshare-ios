//
//  User.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/21/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation
import CoreLocation

var Users = UserStore()

class User {
    let uuid : String
    let name : String

    var localPubKey : Data
    var localPrivKey : Data
    var remotePubKey : Data

    var cap : Int

    private var locations : [CLLocation]

    init(uuid: String, localPrivKey: Data, localPubKey: Data, remotePubKey: Data, name: String) {
        self.uuid = uuid
        self.localPrivKey = localPrivKey
        self.localPubKey = localPubKey
        self.remotePubKey = remotePubKey
        self.name = name
        self.cap = 10
        self.locations = [CLLocation]()
    }

    init(dictionary: [String:AnyObject]) {
        self.uuid = dictionary["uuid"] as! String
        self.name = dictionary["name"] as! String
        self.localPubKey = Data(base64Encoded: dictionary["localPubKey"] as! String)!
        self.localPrivKey = Data(base64Encoded: dictionary["localPrivKey"] as! String)!
        self.remotePubKey = Data(base64Encoded: dictionary["remotePubKey"] as! String)!
        self.cap = 10
        self.locations = (dictionary["locations"] as! [AnyObject]).map { CLLocation(dictionary: $0 as! [String : AnyObject])! }
    }

    func dictionary() -> [String:AnyObject] {
        return synced(lock: self) {
            [
                "uuid": self.uuid as AnyObject,
                "name": self.name as AnyObject,
                "localPubKey": self.localPubKey.base64EncodedString() as AnyObject,
                "localPrivKey": self.localPrivKey.base64EncodedString() as AnyObject,
                "remotePubKey": self.remotePubKey.base64EncodedString() as AnyObject,
                "locations": self.locations.map { $0.dictionary() } as AnyObject
            ]
        }
    }

    func addLocation(location: CLLocation) {
        synced(lock: self) {
            locations.append(location)
            while locations.count > cap {
                locations.removeFirst()
            }
        }
    }

    func getLastLocation() -> CLLocation? {
        return synced(lock: self) { locations.last }
    }
}

class UserStore {
    var version : Int
    private var users : [String:User]

    init() {
        version = 0
        users = [String:User]()
    }

    init(dictionary: [String:AnyObject]) {
        self.version = dictionary["version"] as! Int
        self.users = [String:User]()
        for userEntry in dictionary["users"] as! [AnyObject] {
            let user = User(dictionary: userEntry as! [String:AnyObject])
            self.users[user.uuid] = user
        }
    }

    func dictionary() -> [String:AnyObject] {
        return synced(lock: self) {
            [
                "version": self.version as AnyObject,
                "users": self.users.values.map { $0.dictionary() } as AnyObject
            ]
        }
    }

    func map<T>(closure: @escaping (String, User) -> T) -> [T] {
        return synced(lock: self) {
            self.users.map {
                closure($0, $1)
            }
        }
    }

    func getUser(uuid: String) -> User? {
        return synced(lock: self) {
            self.users[uuid]
        }
    }

    func addUser(user: User) {
        synced(lock: self) {
            self.users[user.uuid] = user
        }
    }
}
