//
//  MessagesViewController.swift
//  MessagesExtension
//
//  Created by Jeremy Kelleher on 8/18/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import UIKit
import Messages
import MapKit

class MessagesViewController: MSMessagesAppViewController {
    
    let regionRadius: CLLocationDistance = 1000
    var locationManager = CLLocationManager()
    
    var locationSearchTable: LocationSearchTable? = nil
    
    var selectedPin: Pinnable? = nil
    var locations: [PinnedLocation] = []
    var searchedPins: [SearchedLocation] = []
    
    @IBOutlet weak var currentLocationHoverBar: ISHHoverBar!
    @IBOutlet weak var savePinsHoverBar: ISHHoverBar!
    
    @IBOutlet weak var map: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        map.delegate = self
        
        // location manager setup
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
        locationManager.delegate = self
        checkLocationAuthorizationStatus()
        
        definesPresentationContext = true
        
        // hover bars
        
        // current location hover bar
        let mapBarButton = MKUserTrackingBarButtonItem(mapView: map)
        
        let searchButton = UIButton(type: .infoDark)
        searchButton.addTarget(self, action: #selector(searchButtonPressed), for: .touchUpInside)
        let searchBarButton = UIBarButtonItem(customView: searchButton)
        self.currentLocationHoverBar.items = [mapBarButton, searchBarButton]
        // TODO - add send map button
        
        // save pins hover bar
        let savePinsButton = UIButton(type: .contactAdd)
        savePinsButton.addTarget(self, action: #selector(savePins), for: .touchUpInside)
        let savePinsBarButton = UIBarButtonItem(customView: savePinsButton)
        savePinsHoverBar.items = [savePinsBarButton]
        savePinsHoverBar.isHidden = true
        
        // pin drop set up
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(addPin))
        map.addGestureRecognizer(gesture)
        
    }
    
    func addPin(gestureRecognizer:UIGestureRecognizer){
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: map)
            let newCoordinates = map.convert(touchPoint, toCoordinateFrom: map)
            
            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: newCoordinates.latitude, longitude: newCoordinates.longitude), completionHandler: {(placemarks, error) -> Void in
                if error != nil {
                    print("Reverse geocoder failed with error \(error!.localizedDescription)")
                    return
                }
                
                if let placemarks = placemarks , placemarks.count > 0 {
                    let placemark = placemarks[0]
                    
                    let annotation = PinnedLocation(title: placemark.name, coordinate: newCoordinates)
                    annotation.placemark = MKPlacemark(placemark: placemark)
                    annotation.subtitle = AddressParser.parse(placemark: MKPlacemark(placemark: placemark))
                    self.map.addAnnotation(annotation)
                    self.locations.append(annotation)
                }
                else {
                    print("Problem with the data received from geocoder")
                }
            })
        }
    }
    
    func savePins() {
        for searchedPin in searchedPins {
            let pin = PinnedLocation(title: searchedPin.title!, subtitle: searchedPin.subtitle!, coordinate: searchedPin.coordinate)
            map.removeAnnotation(searchedPin)
            map.addAnnotation(pin)
            self.locations.append(pin)
        }
        searchedPins.removeAll()
        self.savePinsHoverBar.isHidden = true
    }
    
    func searchButtonPressed() {
        locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as? LocationSearchTable
        locationSearchTable!.mapView = map
        locationSearchTable!.mapSearchDelegate = self
        
        locationSearchTable!.modalPresentationStyle = .custom
        locationSearchTable!.transitioningDelegate = self
        self.present(locationSearchTable!, animated: true, completion: nil)
    }
    
    
    // MARK: - Conversation Handling
    
    override func willBecomeActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the inactive to active state.
        // This will happen when the extension is about to present UI.
        
        // Use this method to configure the extension and restore previously stored state.
    }
    
    override func didResignActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the active to inactive state.
        // This will happen when the user dissmises the extension, changes to a different
        // conversation or quits Messages.
        
        // Use this method to release shared resources, save user data, invalidate timers,
        // and store enough state information to restore your extension to its current state
        // in case it is terminated later.
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        // Called when a message arrives that was generated by another instance of this
        // extension on a remote device.
        
        // Use this method to trigger UI updates in response to the message.
    }
    
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user taps the send button.
    }
    
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        // Called when the user deletes the message without sending it.
    
        // Use this to clean up state related to the deleted message.
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
    
        // Use this method to prepare for the change in presentation style.
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called after the extension transitions to a new presentation style.
    
        // Use this method to finalize any behaviors associated with the change in presentation style.
    }

}

// MARK: - Handle what happens when a search result is tapped
protocol MapSearchDelegate {
    func dropPin(for placemark:MKPlacemark, saveToLocations save: Bool, dismissPresentedVC dismiss: Bool)
    func dropPins(for placemarks:[MKPlacemark])
    func search()
    func clear()
}

extension MessagesViewController: MapSearchDelegate {
    
    func dropPin(for placemark:MKPlacemark, saveToLocations save: Bool = true, dismissPresentedVC dismiss: Bool = false) {
        
        // if the pin is not present, add it
        var annotation: Pinnable
        if save {
            annotation = PinnedLocation(title: placemark.name, coordinate: placemark.coordinate)
            locations.append(annotation as! PinnedLocation)
            centerMapOnLocation(location: placemark.location!)
        } else {
            annotation = SearchedLocation(title: placemark.name, coordinate: placemark.coordinate)
            searchedPins.append(annotation as! SearchedLocation)
        }
        
        annotation.placemark = placemark
        annotation.subtitle = AddressParser.parse(placemark: placemark)
        map.addAnnotation(annotation)
        
        if dismiss {
            self.dismiss(animated: true, completion: nil) // dismiss the presented location search table
        }
    }
    
    func dropPins(for placemarks: [MKPlacemark]) {
        self.dismiss(animated: true, completion: nil) // dismiss the presented location search table
        for placemark in placemarks {
            self.dropPin(for: placemark, saveToLocations: false)
        }
        fitMapRegionForSearchedPins()
        savePinsHoverBar.isHidden = false
    }
    
    func fitMapRegionForSearchedPins() {
        var upper = CLLocationCoordinate2D(latitude: -90.0, longitude: -90.0)
        var lower = CLLocationCoordinate2D(latitude: 90.0, longitude: 90.0)
        for pin in searchedPins {
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

    // TODO - refactor this to move the majority of the functionality to the location search table
    func search() {
        guard let locationSearchTable = self.locationSearchTable else { print("location table not present after search button pressed"); return }
        
        // only drop pins for the addresses (don't include the suggested topics)
        let addresses = locationSearchTable.matchingItems.filter { return $0.subtitle != "" }
        for address in addresses {
            let searchRequest = MKLocalSearchRequest(completion: address)
            let search = MKLocalSearch(request: searchRequest)
            search.start { (response, error) in
                if let placemark = response?.mapItems[0].placemark {
                    self.dropPin(for: placemark, saveToLocations: false)
                }
                if address == addresses.last {
                    self.fitMapRegionForSearchedPins()
                }
            }
        }
        
        self.savePinsHoverBar.isHidden = false
        self.dismiss(animated: true)
    }
    
    func clear() {
        map.removeAnnotations(searchedPins)
        searchedPins = []
        savePinsHoverBar.isHidden = true
    }

}

extension MessagesViewController: UIViewControllerTransitioningDelegate {
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let vc = PresentationController(presentedViewController: presented, presenting: presenting)
        // I really don't want to hardcode the value of topLayoutGuideLength here, but when the extension is in compact mode, topLayoutGuide.length returns 172.0.
        vc.topLayoutGuideLength = topLayoutGuide.length > 100 ? 86.0 : topLayoutGuide.length
        return vc
    }
}


class PresentationController: UIPresentationController {
    
    var topLayoutGuideLength: CGFloat = 0.0
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else {
            return super.frameOfPresentedViewInContainerView
        }
        return CGRect(x: 0, y: topLayoutGuideLength, width: containerView.bounds.width, height: containerView.bounds.height - topLayoutGuideLength)
    }
}


