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
    let username : String
    let name : String
    let session : Session

    var cap : Int

    private var locations : [CLLocation]

    init(username: String, name: String, session: Session) {
        self.username = username
        self.name = name
        self.session = session
        self.cap = 10
        self.locations = [CLLocation]()
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
    var version = 0
    private var users = [String:User]()
    private var notifier : ((_: String) -> Void)?

    func map<T>(closure: @escaping (String, User) -> T) -> [T] {
        return synced(lock: self) {
            self.users.map {
                closure($0, $1)
            }
        }
    }

    func map(closure: @escaping (String, User) -> Void) {
        _ = synced(lock: self) {
            self.users.map {
                closure($0, $1)
            }
        }
    }

    func getUser(username: String) -> User? {
        return synced(lock: self) {
            self.users[username]
        }
    }

    func addUser(user: User) {
        synced(lock: self) {
            self.users[user.username] = user
        }
    }

    func setNotifier(notifier: @escaping (_: String) -> Void) {
        self.notifier = notifier
    }

    func notify(username: String) {
        self.notifier?(username)
    }
}
