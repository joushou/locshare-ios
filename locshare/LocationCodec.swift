//
//  LocationCodec.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/20/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import CoreLocation
import Foundation

extension CLPlacemark {
    var singleLine : String {
        var locationStr = ""
        if let thoroughfare = self.thoroughfare {
            locationStr += thoroughfare
        }

        if let locality = self.locality {
            if (locationStr.characters.count > 0) {
                locationStr += ", "
            }

            if let subLocality = self.subLocality {
                locationStr += subLocality + ", " + locality
            } else {
                locationStr += locality
            }
        }

        if let country = self.country {
            if (locationStr.characters.count > 0) {
                locationStr += ", "
            }
            locationStr += country
        }
        
        return locationStr
    }
}

extension CLLocationCoordinate2D {
    var coordinateString : String {
        let latitudeSuffix = latitude >= 0 ? "N" : "S"
        let longitudeSuffix = longitude >= 0 ? "E" : "W"

        return String(format: "%.5f°\(latitudeSuffix) %.5f°\(longitudeSuffix)",
            abs(latitude),
            abs(longitude))
    }
}

extension CLLocation {
    func marshalledData() -> Data {
        var buf = Data()

        buf.append(typetobinary((self.timestamp.timeIntervalSince1970*1000).bitPattern.bigEndian))
        buf.append(typetobinary((self.horizontalAccuracy).bitPattern.bigEndian))
        buf.append(typetobinary((self.coordinate.latitude).bitPattern.bigEndian))
        buf.append(typetobinary((self.coordinate.longitude).bitPattern.bigEndian))
        buf.append(typetobinary((self.altitude).bitPattern.bigEndian))
        buf.append(typetobinary((self.course).bitPattern.bigEndian))
        buf.append(typetobinary((self.speed).bitPattern.bigEndian))

        return buf
    }

    convenience init(marshalledData: Data) {
        let bytes = marshalledData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: marshalledData.count))
        }

        let time = Double(bitPattern: binarytotype(bytes[Range(0..<8)], UInt64.self).bigEndian)
        let accuracy = Double(bitPattern: binarytotype(bytes[Range(8..<16)], UInt64.self).bigEndian)
        let latitude = Double(bitPattern: binarytotype(bytes[Range(16..<24)], UInt64.self).bigEndian)
        let longitude = Double(bitPattern: binarytotype(bytes[Range(24..<32)], UInt64.self).bigEndian)
        let altitude = Double(bitPattern: binarytotype(bytes[Range(32..<40)], UInt64.self).bigEndian)
        let course = Double(bitPattern: binarytotype(bytes[Range(40..<48)], UInt64.self).bigEndian)
        let speed = Double(bitPattern: binarytotype(bytes[Range(48..<56)], UInt64.self).bigEndian)

        self.init(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                  altitude: altitude,
                  horizontalAccuracy: accuracy,
                  verticalAccuracy: 1,
                  course: course,
                  speed: speed,
                  timestamp: Date(timeIntervalSince1970: time/1000))
    }

    convenience init?(dictionary: [String:AnyObject]) {
        if let dict = dictionary as? [String:Double] {
            self.init(coordinate: CLLocationCoordinate2D(latitude: dict["latitude"]!, longitude: dict["longitude"]!),
                      altitude: dict["altitude"]!,
                      horizontalAccuracy: dict["accuracy"]!,
                      verticalAccuracy: 1,
                      course: dict["bearing"]!,
                      speed: dict["speed"]!,
                      timestamp: Date(timeIntervalSince1970: dict["time"]!/1000))
        } else {
            return nil
        }
    }

    func dictionary() -> [String:AnyObject] {
        let dict:[String:Double] = [
            "latitude": self.coordinate.latitude,
            "longitude": self.coordinate.longitude,
            "altitude": self.altitude,
            "accuracy": self.horizontalAccuracy,
            "bearing": self.course,
            "speed": self.speed,
            "time": self.timestamp.timeIntervalSince1970*1000
        ]
        return dict as [String:AnyObject]
    }
}
