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
    var instructions: CompactInstructionsViewController? = nil
    
    var selectedPin: Pinnable? = nil
    var locations: [PinnedLocation]  = [] {
        didSet {
            if locations.isEmpty {
                searchHoverBar.items = [searchButton!]
            }
        }
    }
    var searchedPins: [SearchedLocation] = []
    
    @IBOutlet weak var currentLocationHoverBar: ISHHoverBar!
    @IBOutlet weak var searchHoverBar: ISHHoverBar!
    var searchButton: UIBarButtonItem? = nil
    var savePinsButton: UIBarButtonItem? = nil
    var removePinsButton: UIBarButtonItem? = nil
    
    
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
        let mapBarButton = MKUserTrackingBarButtonItem(mapView: map)
        let sendButton = hoverBarButton(imageName: "send", selector: #selector(sendLocations))
        self.currentLocationHoverBar.items = [mapBarButton, sendButton]
        
        searchButton = hoverBarButton(imageName: "search", selector: #selector(searchButtonPressed))
        savePinsButton = hoverBarButton(imageName: "addLocation", selector: #selector(savePins))
        removePinsButton = hoverBarButton(imageName: "removeLocation", selector: #selector(removeSavedPins))
        searchHoverBar.items = [searchButton!]
        
        // pin drop set up
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(addPin))
        map.addGestureRecognizer(gesture)
        
        instructions = storyboard!.instantiateViewController(withIdentifier: "CompactInstructionsViewController") as? CompactInstructionsViewController
    }
    
    func handle(presentationStyle: MSMessagesAppPresentationStyle) {
        switch presentationStyle {
        case .compact:
            self.present(instructions!, animated: false, completion: nil)
        case .expanded:
            self.dismiss(animated: false, completion: nil)
        }
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
        searchHoverBar.items = [searchButton!, removePinsButton!]
    }
    
    func savePins() {
        for searchedPin in searchedPins {
            let pin = PinnedLocation(title: searchedPin.title!, subtitle: searchedPin.subtitle!, coordinate: searchedPin.coordinate)
            map.removeAnnotation(searchedPin)
            map.addAnnotation(pin)
            self.locations.append(pin)
        }
        searchedPins.removeAll()
        searchHoverBar.items = [searchButton!, removePinsButton!]
    }
    
    // TODO - add remove pins button
    func removeSavedPins() {
        locations = []
        self.map.removeAnnotations(self.map.annotations)
        searchHoverBar.items = [searchButton!]
    }
    
    func sendLocations() {
        var components = URLComponents()
        let items = locations.flatMap { $0.queryItems }
        components.queryItems = items
        let message = MSMessage(session: MSSession())
        message.url = components.url!
        // TODO - layout
        
        guard let conversation = activeConversation else { fatalError("Expected a conversation") }
        conversation.insert(message) { error in
            if let error = error {
                print(error)
            }
        }
        requestPresentationStyle(.compact)
//        handle(presentationStyle: .compact)
    }
    
    func searchButtonPressed() {
        locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as? LocationSearchTable
        locationSearchTable!.mapView = map
        locationSearchTable!.mapSearchDelegate = self
        
        locationSearchTable!.modalPresentationStyle = .custom
        locationSearchTable!.transitioningDelegate = self
        self.present(locationSearchTable!, animated: true, completion: nil)
    }
    
    func hoverBarButton(imageName: String, selector: Selector) -> UIBarButtonItem {
        let button = UIButton(frame: CGRect(origin: CGPoint(), size: CGSize(width: 30, height: 30)))
        button.setImage(UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        button.tintColor = .blue
        button.addTarget(self, action: selector, for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }
    
    
    // MARK: - Conversation Handling
    
    // conversation.selectedMessage != nil when tapping on a message
    override func willBecomeActive(with conversation: MSConversation) {
        // Called when the extension is about to move from the inactive to active state.
        // This will happen when the extension is about to present UI.
        
        // Use this method to configure the extension and restore previously stored state.
        if let message = conversation.selectedMessage {
            handle(received: message)
        } else {
           handle(presentationStyle: self.presentationStyle)
        }
    }
   
    // only when the application is running
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        self.handle(received: message)
    }
    
    func handle(received message: MSMessage) {
        let url = message.url
        guard let urlComponents = NSURLComponents(url: url!, resolvingAgainstBaseURL: false),
            let queryItems = urlComponents.queryItems, queryItems.count % 2 == 0 else { return }
        var coordinates: [[URLQueryItem]] = []
        for i in 0..<queryItems.count {
            if (i % 2 == 0) {
                let pair = [queryItems[i], queryItems[i+1]]
                coordinates.append(pair)
            } else {
                continue
            }
        }
        map.removeAnnotations(map.annotations) // FIXME - this will delete user data if user has pins already on the map
        locations = coordinates.map{ PinnedLocation(queryItems: $0)! }
        map.addAnnotations(locations)
        searchHoverBar.items = [searchButton!, removePinsButton!]
    }
    
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
    
        // Use this method to prepare for the change in presentation style.
        
        handle(presentationStyle: presentationStyle)
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
            searchHoverBar.items = [searchButton!, removePinsButton!]
        } else {
            annotation = SearchedLocation(title: placemark.name, coordinate: placemark.coordinate)
            searchedPins.append(annotation as! SearchedLocation)
            searchHoverBar.items = [searchButton!, savePinsButton!]
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
        
        self.dismiss(animated: true)
        searchHoverBar.items = [searchButton!, savePinsButton!]
    }
    
    func clear() {
        map.removeAnnotations(searchedPins)
        searchedPins = []
        if locations.isEmpty {
            searchHoverBar.items = [searchButton!]
        } else {
            searchHoverBar.items = [searchButton!, savePinsButton!]
        }
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

// TODO - handle state changes of adding, dropping with hover bar buttons using enums
// when searching, add a pin, then hit remove all, the add searched pins button disapears

