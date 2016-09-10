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
            directions.backgroundColor = UIColor.blue
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
            searchedPins = self.searchedPins.filter() { $0.placemark != selectedPin.placemark }
            
            let pinToSave = PinnedLocation(title: selectedPin.title!, subtitle: selectedPin.subtitle!, coordinate: selectedPin.coordinate)
            locations.append(pinToSave)
            self.map.addAnnotation(pinToSave)
        }
    }
    
    func removeLocation() {
        if let selectedPin = selectedPin {
            self.map.removeAnnotation(selectedPin)
            locations = locations.filter() { $0.placemark != selectedPin.placemark }
        }
    }

}
