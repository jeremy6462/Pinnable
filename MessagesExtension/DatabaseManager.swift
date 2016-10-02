//
//  DatabaseManager.swift
//  Pinnable
//
//  Created by Jeremy Kelleher on 9/30/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import Foundation
import MapKit

let PINNABLE_DATABASE_KEY = "Pinnable_Saved_Pin_"

class DatabaseManager {
    
    // MARK - User's last locations
    
    class func saveLastUser(latitude: Double, longitude: Double) {
        UserDefaults.standard.set(longitude, forKey: "LastLongitude")
        UserDefaults.standard.set(latitude, forKey: "LastLatitude")
    }
    
    // using the object(forKey:) so that I can use optional binding to handle the case where no long and lat are stored in the database
    // if I used double(forKey:) and there were no long or lat, the method would return 0, which is not the kind of error handling I want
    class func loadLastUserLocation() -> CLLocation? {
        if let longitude = UserDefaults.standard.object(forKey: "LastLongitude") as? Double,
            let latitude = UserDefaults.standard.object(forKey: "LastLatitude") as? Double { // FIXME - doesn't save latitude. may need to switch to double(forKey:)
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        return nil
    }
    
    // MARK - Most recent pins
    
    class func save(pin: PinnedLocation) {
        let key = PINNABLE_DATABASE_KEY + pin.identifier
        let value = encode(pin: pin)
        let database = UserDefaults.standard
        database.set(value, forKey: key)
    }
    
    class func lastPins() -> [PinnedLocation] {
        
        // an array of all the keys in the database that include the pinnable database key
        let database = UserDefaults.standard
        let savedPinKeys = database.dictionaryRepresentation().keys.filter({ $0.range(of: PINNABLE_DATABASE_KEY) != nil })
        
        var pins: [PinnedLocation] = []
        for pinKey in savedPinKeys {
            let savedPinCoordinates = database.dictionary(forKey: pinKey)
            guard let savedPin = decode(coordinates: savedPinCoordinates as! [String : Double]) else { continue }
            let identifier = pinKey.replacingOccurrences(of: PINNABLE_DATABASE_KEY, with: "")
            savedPin.identifier = identifier
            pins.append(savedPin)
        }
        return pins
    }
    
    class func remove(pin: PinnedLocation) {
        let key = PINNABLE_DATABASE_KEY + pin.identifier
        let database = UserDefaults.standard
        database.removeObject(forKey: key)
    }
    
    class func encode(pin: PinnedLocation) -> [String: Double] {
        return [LAT_KEY: pin.coordinate.latitude, LONG_KEY: pin.coordinate.longitude]
    }
    
    class func decode(coordinates: [String: Double]) -> PinnedLocation? {
        return PinnedLocation(coordinates: coordinates) ?? nil
    }
    
}
