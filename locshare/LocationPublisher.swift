//
//  LocationPublisher.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/17/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation
import CoreLocation

var lastLocation : CLLocation?

class LocationPublisher : NSObject, CoreLocation.CLLocationManagerDelegate {
    var locationManager:CLLocationManager?

    func setupLocationManager() {
        if locationManager != nil {
            return
        }

        let locmgr = CLLocationManager()
        locmgr.delegate = self
        locmgr.requestAlwaysAuthorization()
        locmgr.pausesLocationUpdatesAutomatically = true
        locmgr.activityType = CoreLocation.CLActivityType.other
        locmgr.allowsBackgroundLocationUpdates = true
        locmgr.desiredAccuracy = kCLLocationAccuracyKilometer
        locmgr.distanceFilter = 50
        locationManager = locmgr
    }

    func startBackgroundLocationUpdates() {
        setupLocationManager()
        self.locationManager?.startUpdatingLocation()
        self.locationManager?.startMonitoringSignificantLocationChanges()
    }


    func monitorSignificantChanges() {
        setupLocationManager()
        locationManager?.stopUpdatingLocation()
        locationManager?.startMonitoringSignificantLocationChanges()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager?.startMonitoringSignificantLocationChanges()
        lastLocation = locations.last
        DispatchQueue.global().async {
            for i in 0 ..< locations.count {
                let thing = locations[i].marshalledData()
                Users.map {
                    let session = $1.session
                    let msg = session.encrypt(thing)
                    GlobalClient.push(username: $1.username, message: msg, finished: {_ in 
                    })
                }
            }
        }
    }
}
