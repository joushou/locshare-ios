//
//  LocationCodec.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/20/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import CoreLocation
import Foundation

func binarytotype <T> (_ value: [UInt8], _: T.Type) -> T {
    return value.withUnsafeBufferPointer {
        $0.baseAddress!
            .withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
        }
    }
}

func binarytotype <T> (_ value: ArraySlice<UInt8>, _: T.Type) -> T {
    return value.withUnsafeBufferPointer {
        $0.baseAddress!
            .withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
        }
    }
}

func typetobinary <T> (_ value: T) -> [UInt8] {
    var mv : T = value
    let s : Int = MemoryLayout<T>.size
    return withUnsafePointer(to: &mv) {
        $0.withMemoryRebound(to: UInt8.self, capacity: s) {
            Array(UnsafeBufferPointer(start: $0, count: s))
        }
    }
}

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
        var arr = [UInt8]()
        arr.append(contentsOf: typetobinary((self.timestamp.timeIntervalSince1970*1000).bitPattern.bigEndian))
        arr.append(contentsOf: typetobinary((self.horizontalAccuracy).bitPattern.bigEndian))
        arr.append(contentsOf: typetobinary((self.coordinate.latitude).bitPattern.bigEndian))
        arr.append(contentsOf: typetobinary((self.coordinate.longitude).bitPattern.bigEndian))
        arr.append(contentsOf: typetobinary((self.altitude).bitPattern.bigEndian))
        arr.append(contentsOf: typetobinary((self.course).bitPattern.bigEndian))
        arr.append(contentsOf: typetobinary((self.speed).bitPattern.bigEndian))

        return Data(bytes: arr)
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
