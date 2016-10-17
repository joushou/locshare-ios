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
    var inputStream:InputStream!
    var outputStream:OutputStream!
    var locationManager:CLLocationManager!

    func startBackgroundLocationUpdates() {
        // Create a location manager object
        self.locationManager = CLLocationManager()

        // Set the delegate
        self.locationManager.delegate = self

        // Request location authorization
        self.locationManager.requestAlwaysAuthorization()

        // Set an accuracy level. The higher, the better for energy.
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers

        // Enable automatic pausing
        self.locationManager.pausesLocationUpdatesAutomatically = true

        // Specify the type of activity your app is currently performing
        self.locationManager.activityType = CoreLocation.CLActivityType.other;

        // Enable background location updates
        self.locationManager.allowsBackgroundLocationUpdates = true

        self.locationManager.distanceFilter = 50

        // Start location updates
        self.locationManager.startUpdatingLocation()
        self.locationManager.startMonitoringSignificantLocationChanges()

    }

    func connect(ip_address: String, port: Int) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(nil, ip_address as CFString!, UInt32(port), &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        inputStream?.open()
        outputStream?.open()
    }

    func close() {
        inputStream?.close()
        outputStream?.close()
    }

    func push(_ string: String, encoding: String.Encoding = String.Encoding.utf8) -> Int {
        if let data = string.data(using: encoding, allowLossyConversion: false) {
            var bytesRemaining = data.count
            var totalBytesWritten = 0

            while bytesRemaining > 0 {
                let bytesWritten = data.withUnsafeBytes {
                    outputStream.write(
                        $0.advanced(by: totalBytesWritten),
                        maxLength: bytesRemaining
                    )
                }
                if bytesWritten < 0 {
                    return -1
                } else if bytesWritten == 0 {
                    return totalBytesWritten
                }

                bytesRemaining -= bytesWritten
                totalBytesWritten += bytesWritten
            }

            return totalBytesWritten
        }

        return -1
    }

    func monitorSignificantChanges() {
        self.locationManager.stopUpdatingLocation()
        self.locationManager.startMonitoringSignificantLocationChanges()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.locationManager.startMonitoringSignificantLocationChanges()
        lastLocation = locations.last
        DispatchQueue.global().async {
            let defaults = UserDefaults.standard
            let ip_address = defaults.string(forKey: "server_preference")!
            let port = defaults.integer(forKey: "port_preference")
            self.connect(ip_address: ip_address, port: port)

            // Perform location-based activity
            NSLog("--- locations = \(locations)\n")

            var str = ""

            for i in 0 ..< locations.count {
                let thing = locations[i].marshalledData()
                let keys = Users.map {
                    $1.remotePubKey
                }

                for key in keys {
                    let blob = encryptWithCurve25519PublicKey(plain_text: thing, public_key: key)!
                    str += "pub " + key.base64EncodedString() + " " + blob.base64EncodedString() + "\n"
                }
            }

            str += "close\n"
            _ = self.push(str)
            self.close()
        }
    }

}
