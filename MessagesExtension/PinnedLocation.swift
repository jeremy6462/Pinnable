//
//  PinnedLocation.swift
//  Map
//
//  Created by Jeremy Kelleher on 7/10/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import Foundation
import MapKit

let LAT_KEY = "lat"
let LONG_KEY = "long"

class PinnedLocation: NSObject, MKAnnotation, Pinnable {
    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D {
        didSet {
            reset(newLocation: coordinate)
        }
    }
    var placemark: MKPlacemark?
    var pinColor: UIColor = UIColor.green
    var identifier: String = NSUUID().uuidString
    
    init(title: String? = nil, subtitle: String? = nil, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
        super.init()
    }
}

class SearchedLocation: NSObject, MKAnnotation, Pinnable {
    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D
    var placemark: MKPlacemark?
    var pinColor: UIColor = UIColor.red
    var identifier: String = NSUUID().uuidString
    
    init(title: String? = nil, subtitle: String? = nil, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
        super.init()
    }
}

protocol Pinnable: MKAnnotation {
    var title: String? { get set }
    var subtitle: String? { get set }
    var coordinate: CLLocationCoordinate2D { get set }
    var placemark: MKPlacemark? { get set }
    var pinColor: UIColor { get }
    var identifier: String { get set }
}

// MARK - Handles pin dragging and dropping

extension Pinnable {
    
    // resets the Pinnable's properties after the pin is dragged to a new location so that the address is up-to-date
    func reset(newLocation coordinate: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), completionHandler: {(placemarks, error) -> Void in
            if error != nil {
                print("Reverse geocoder failed with error \(error!.localizedDescription)")
                return
            }
            
            if let placemarks = placemarks , placemarks.count > 0 {
                let placemark = placemarks[0]
                
                self.placemark = MKPlacemark(placemark: placemark)
                self.title = placemark.name
                self.subtitle = AddressParser.parse(placemark: MKPlacemark(placemark: placemark))
            }
            else {
                print("Problem with the data received from geocoder")
            }
        })
    }
}

// MARK - query items for iMessage Apps

extension PinnedLocation {
    var queryItems: [URLQueryItem] {
        return [URLQueryItem(name: "lat", value: String(self.coordinate.latitude)),
                URLQueryItem(name: "long", value: String(self.coordinate.longitude))]
    }
    
    // Pre-condition - query items should hold two elements, lat and long
    convenience init?(queryItems: [URLQueryItem]) {
        if queryItems.count != 2 { return nil }
        
        var latitude: Double
        var longitude: Double
        
        let itemA = queryItems[0]
        let itemB = queryItems[1]
        
        guard let valueA = itemA.value else { return nil }
        guard let valueB = itemB.value else { return nil }
        
        if itemA.name == LAT_KEY {
            latitude = Double(valueA)! // FIXME - if value is not a double could crash
        } else if itemB.name == LAT_KEY {
            latitude = Double(valueB)!
        } else {
            return nil
        }
        
        if itemA.name == LONG_KEY {
            longitude = Double(itemA.value!)!
        } else if itemB.name == LONG_KEY {
            longitude = Double(itemB.value!)!
        } else {
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.init(coordinate: coordinate)
        
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude), completionHandler: {(placemarks, error) -> Void in
            if error != nil {
                print("Reverse geocoder failed with error \(error!.localizedDescription)")
                return
            }
            if let placemarks = placemarks, placemarks.count > 0 {
                let placemark = placemarks[0]
                self.title = placemark.name
                self.subtitle = AddressParser.parse(placemark: MKPlacemark(placemark: placemark))
                self.placemark = MKPlacemark(placemark: placemark)
            }
            else {
                print("Problem with the data received from geocoder")
            }
        })
    }
}




