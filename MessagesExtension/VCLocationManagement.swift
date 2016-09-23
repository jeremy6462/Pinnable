//
//  VCLocationManagement.swift
//  Map
//
//  Created by Jeremy Kelleher on 7/10/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import UIKit
import MapKit

extension MessagesViewController: CLLocationManagerDelegate {
    
    func checkLocationAuthorizationStatus() {
        handleAuthorization(status: CLLocationManager.authorizationStatus())
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorization(status: status)
    }
    
    func handleAuthorization(status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse:
            locationManager.requestLocation()
            allowLocationTracking()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            doesntAllowLocationTracking()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            centerMapOnLocation(location: location)
            save(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }
    
    // MARK - Utilities
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        map.setRegion(coordinateRegion, animated: true)
    }
    
    func allowLocationTracking() {
        map.showsUserLocation = true
        allowsLocationTracking = true
    }
    
    func doesntAllowLocationTracking() {
        map.showsUserLocation = false
        allowsLocationTracking = false
    }
    
    func handle(userLocationAllowed allowed: Bool) {
        switch allowed {
        case true:
            self.currentLocationHoverBar.items = [mapBarButton!, sendButton!]
        case false:
            self.currentLocationHoverBar.items = [sendButton!]
        }
    }
    
    // MARK - Error Handling
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if CLLocationManager.authorizationStatus() == .denied {
            print("User has denied location services");
        } else {
            print("Location manager did fail with error: \(error)")
        }
    }

}

// MARK - Database access for last location information for centering the map on subsequent startups

extension MessagesViewController {
    
    func save(latitude: Double, longitude: Double) {
        UserDefaults.standard.set(longitude, forKey: "LastLongitude")
        UserDefaults.standard.set(latitude, forKey: "LastLatitude")
    }
    
    // using the object(forKey:) so that I can use optional binding to handle the case where no long and lat are stored in the database
    // if I used double(forKey:) and there were no long or lat, the method would return 0, which is not the kind of error handling I want
    func loadLastUserLocation() -> CLLocation? {
        if let longitude = UserDefaults.standard.object(forKey: "LastLongitude") as? Double,
            let latitude = UserDefaults.standard.object(forKey: "LastLatitude") as? Double { // FIXME - doesn't save latitude. may need to switch to double(forKey:)
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        return nil
    }
    
}
