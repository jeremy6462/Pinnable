//
//  PinnedLocation.swift
//  Map
//
//  Created by Jeremy Kelleher on 7/10/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import Foundation
import MapKit

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
}

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



