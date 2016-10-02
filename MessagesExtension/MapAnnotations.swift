//
//  VCMapView.swift
//  Map
//
//  Created by Jeremy Kelleher on 7/7/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import Foundation
import MapKit

extension MessagesViewController: MKMapViewDelegate {
    
    enum AnnotationTag: Int {
        case directions = 1
        case locationListModifier = 2
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? Pinnable {
            let identifier = "pin"
            var view: MKPinAnnotationView
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.animatesDrop = true
            view.pinTintColor = annotation.pinColor
            
            // directions button
            let directionsSize = CGSize(width: 50, height: 50)
            let directions = UIButton(frame: CGRect(origin: CGPoint(), size: directionsSize))
            let car = UIImage(named: "car")
            directions.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
            directions.setImage(car, for: .normal)
            view.leftCalloutAccessoryView = directions
            
            // add/remove from location list
            var imageName: String
            if annotation is PinnedLocation {
                imageName = "removeLocation"
                view.isDraggable = true
            } else { // it's a searched pin
                imageName = "addLocation"
            }
            let locationsListModifierSize = CGSize(width: 30, height: 30)
            let locationListModifier = UIButton(frame: CGRect(origin: CGPoint(), size: locationsListModifierSize))
            locationListModifier.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal), for: .normal)
            view.rightCalloutAccessoryView = locationListModifier
            
            view.canShowCallout = true
            
            return view
        }
        return nil
    }
    

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        selectedPin = view.annotation as? Pinnable
    }
    
    // MARK - Accessory Button
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == view.leftCalloutAccessoryView {
            getDirections()
        }
        else if control == view.rightCalloutAccessoryView {
            locationListModifier()
        }
    }
    
    func getDirections() {
        if let selectedPin = selectedPin, let placemark = selectedPin.placemark {
            let mapItem = MKMapItem(placemark: placemark)
            let launchOptions = [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving]
            mapItem.openInMaps(launchOptions: launchOptions)
        }
    }
    
    func locationListModifier() {
        if let selectedPin = selectedPin {
            if selectedPin is PinnedLocation {
                removeLocation()
            } else {
                addLocation()
            }
        }
    }
    
    func addLocation() {
        if let selectedPin = selectedPin {
            self.map.removeAnnotation(selectedPin)
            searchedPins = self.searchedPins.filter() { $0.identifier != selectedPin.identifier }
            
            let pinToSave = PinnedLocation(title: selectedPin.title!, subtitle: selectedPin.subtitle!, coordinate: selectedPin.coordinate)
            locations.append(pinToSave)
            self.map.addAnnotation(pinToSave)
            DatabaseManager.save(pin: pinToSave)
        }
    }
    
    func removeLocation() {
        if let selectedPin = selectedPin {
            self.map.removeAnnotation(selectedPin)
            locations = locations.filter() { $0.identifier != selectedPin.identifier }
            DatabaseManager.remove(pin: selectedPin as! PinnedLocation)
        }
    }

}

// Pin related methods

extension MessagesViewController {
    
    func mapHasPins() -> Bool {
        let pins = map.annotations.flatMap({ $0 as? Pinnable })
        return !pins.isEmpty
    }
    
    func fitMapForPins() {
        
        let pins = map.annotations.flatMap({ $0 as? Pinnable })
        if pins.isEmpty { return }
        
        var upper = CLLocationCoordinate2D(latitude: -90.0, longitude: -90.0)
        var lower = CLLocationCoordinate2D(latitude: 90.0, longitude: 90.0)
        
        for pin in pins {
            if pin.coordinate.latitude > upper.latitude { upper.latitude = pin.coordinate.latitude }
            if pin.coordinate.latitude < lower.latitude { lower.latitude = pin.coordinate.latitude }
            if pin.coordinate.longitude > upper.longitude { upper.longitude = pin.coordinate.longitude }
            if pin.coordinate.longitude < lower.longitude { lower.longitude = pin.coordinate.longitude }
        }
        
        let locationSpan = MKCoordinateSpan(latitudeDelta: upper.latitude - lower.latitude, longitudeDelta: upper.longitude - lower.longitude)
        let locationCenter = CLLocationCoordinate2D(latitude: (upper.latitude + lower.latitude) / 2, longitude: (upper.longitude + lower.longitude) / 2)
        
        let region = MKCoordinateRegionMake(locationCenter, locationSpan)
        map.setRegion(region, animated: true)
    }
    
    // returns true if that pin was present. False if the pin was not present
    func isPinned(placemark: MKPlacemark) -> Bool {
        let latitude = placemark.coordinate.latitude
        let longitude = placemark.coordinate.longitude
        for annotation in map.annotations {
            if let pin = annotation as? Pinnable {
                if pin.coordinate.latitude == latitude && pin.coordinate.longitude == longitude {
                    return true
                }
            }
        }
        return false
    }
    
}
