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
            reloadSearchHoverBar()
        }
    }
    var searchedPins: [SearchedLocation] = [] {
        didSet {
            reloadSearchHoverBar()
        }
    }
    
    @IBOutlet weak var currentLocationHoverBar: ISHHoverBar!
    var mapBarButton: UIBarButtonItem? = nil
    var sendButton: UIBarButtonItem? = nil
    
    var allowsLocationTracking = false {
        didSet {
            if mapBarButton != nil {
                self.handle(userLocationAllowed: allowsLocationTracking)
            }
        }
    }
    
    @IBOutlet weak var searchHoverBar: ISHHoverBar!
    var searchButton: UIBarButtonItem? = nil
    var savePinsButton: UIBarButtonItem? = nil
    var removePinsButton: UIBarButtonItem? = nil
    
    
    @IBOutlet weak var map: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        map.delegate = self
        if let lastUserLocation = loadLastUserLocation() {
            centerMapOnLocation(location: lastUserLocation)
        }
        
        // location manager setup
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
        locationManager.delegate = self
        checkLocationAuthorizationStatus()
        
        definesPresentationContext = true
        
        // hover bars
        mapBarButton = MKUserTrackingBarButtonItem(mapView: map)
        sendButton = hoverBarButton(imageName: "send", selector: #selector(sendLocations))

        
        searchButton = hoverBarButton(imageName: "search", selector: #selector(searchButtonPressed))
        savePinsButton = hoverBarButton(imageName: "addLocation", selector: #selector(savePins))
        removePinsButton = hoverBarButton(imageName: "removeLocation", selector: #selector(removeSavedPins))
        
        let lastUsedPins = lastPins()
        if !lastUsedPins.isEmpty {
            locations = lastUsedPins
            map.removeAnnotations(map.annotations)
            map.addAnnotations(locations)
        }
        
        reloadSearchHoverBar()
        
        // pin drop set up
        
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(addPin))
        map.addGestureRecognizer(gesture)
        
        instructions = storyboard!.instantiateViewController(withIdentifier: "CompactInstructionsViewController") as? CompactInstructionsViewController
        
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
                    self.saveToDatabase(pin: annotation)
                }
                else {
                    print("Problem with the data received from geocoder")
                }
            })
        }
    }
}

// MARK: - Conversation Handling
extension MessagesViewController {
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        // Called before the extension transitions to a new presentation style.
        // Use this method to prepare for the change in presentation style.
        handle(presentationStyle: presentationStyle)
    }
    
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
    
    func handle(presentationStyle: MSMessagesAppPresentationStyle) {
        switch presentationStyle {
        case .compact:
            self.present(instructions!, animated: false, completion: nil)
        case .expanded:
            self.dismiss(animated: false, completion: nil)
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
        map.removeAnnotations(map.annotations) // FIXME - this will delete user data if user has pins already on the map. TODO - Save users maps in Core Data
        locations.forEach({ removeFromDatabase(pin: $0) }) // removing from db because we don't want pins that the user saved for this new map to affect their old map (currently in defaults) may be a bad reason
        locations = coordinates.map{ PinnedLocation(queryItems: $0)! }
        // intentionally not saving these locations to the defaults because the user may not want these. If they want to see them, they can just look them up again by tapping the message
        map.addAnnotations(locations)
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
        
        // if the placemark has already been pinned, don't pin it
        if isPinned(placemark: placemark) {
            if dismiss {
                self.dismiss(animated: true, completion: nil) // dismiss the presented location search table
                return
            } else {
                return
            }
        }
        
        var annotation: Pinnable
        if save {
            annotation = PinnedLocation(title: placemark.name, coordinate: placemark.coordinate)
            locations.append(annotation as! PinnedLocation)
            saveToDatabase(pin: annotation as! PinnedLocation)
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
    }
    
    func clear() {
        map.removeAnnotations(searchedPins)
        searchedPins = []
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

// MARK - hover bars
extension MessagesViewController {
    
    func reloadSearchHoverBar() {
        var buttons = [searchButton!]
        if !searchedPins.isEmpty {
            buttons.append(savePinsButton!)
        }
        if !locations.isEmpty {
            buttons.append(removePinsButton!)
        }
        searchHoverBar.items = buttons
    }
    
    func savePins() {
        for searchedPin in searchedPins {
            let pin = PinnedLocation(title: searchedPin.title!, subtitle: searchedPin.subtitle!, coordinate: searchedPin.coordinate)
            map.removeAnnotation(searchedPin)
            map.addAnnotation(pin)
            self.locations.append(pin)
            saveToDatabase(pin: pin)
        }
        searchedPins = []
    }
    
    func removeSavedPins() {
        locations.forEach({ removeFromDatabase(pin: $0) })
        locations = []
        self.map.removeAnnotations(self.map.annotations)
    }
    
    func sendLocations() {
        
        let message = MSMessage(session: MSSession())
        
        var components = URLComponents()
        let items = locations.flatMap { $0.queryItems }
        components.queryItems = items
        message.url = components.url!
        
        let square = CGSize(width: self.view.frame.width, height: self.view.frame.width)
        UIGraphicsBeginImageContextWithOptions(square, false, UIScreen.main.scale)
        self.map.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        let layout = MSMessageTemplateLayout()
        layout.caption = "Pinnable Map"
        layout.image = image
        message.layout = layout
        
        guard let conversation = activeConversation else { fatalError("Expected a conversation") }
        conversation.insert(message) { error in
            if let error = error {
                print(error)
            }
        }
        requestPresentationStyle(.compact)
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
        button.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        button.tintColor = .blue
        button.addTarget(self, action: selector, for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }
    
}

// Database access

let PINNABLE_DATABASE_KEY = "Pinnable_Saved_Pin_"

extension MessagesViewController {
    
    // MARK - User's last locations
    
    func saveLastUser(latitude: Double, longitude: Double) {
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
    
    // MARK - Most recent pins
    
    func saveToDatabase(pin: PinnedLocation) {
        let key = PINNABLE_DATABASE_KEY + pin.identifier
        let value = encode(pin: pin)
        let database = UserDefaults.standard
        database.set(value, forKey: key)
    }
    
    func lastPins() -> [PinnedLocation] {
        
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
    
    func removeFromDatabase(pin: PinnedLocation) {
        let key = PINNABLE_DATABASE_KEY + pin.identifier
        let database = UserDefaults.standard
        database.removeObject(forKey: key)
    }
    
    func encode(pin: PinnedLocation) -> [String: Double] {
        return [LAT_KEY: pin.coordinate.latitude, LONG_KEY: pin.coordinate.longitude]
    }
    
    func decode(coordinates: [String: Double]) -> PinnedLocation? {
        return PinnedLocation(coordinates: coordinates) ?? nil
    }
    
    
}

