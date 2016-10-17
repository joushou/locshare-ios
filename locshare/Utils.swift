//
//  Utils.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/22/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation
import CoreLocation

func synced<T>(lock: AnyObject, closure: () -> T) -> T {
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }
    return closure()
}
