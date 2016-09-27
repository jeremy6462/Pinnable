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
            saveLastUser(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
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

