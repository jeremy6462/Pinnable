//
//  LocationSearchTable.swift
//  Map
//
//  Created by Jeremy Kelleher on 7/13/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import UIKit
import MapKit

class LocationSearchTable : UITableViewController {
    
    var matchingItems:[MKLocalSearchCompletion] = []
    var mapView: MKMapView? = nil
    
    var handleMapSearchDelegate:HandleMapSearch? = nil

}

extension LocationSearchTable : UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let mapView = mapView, let searchBarText = searchController.searchBar.text else { return }
        if searchBarText == "" { return }
        let completor = MKLocalSearchCompleter()
        completor.filterType = .locationsAndQueries
        completor.queryFragment = searchBarText
        completor.region = mapView.region
        completor.delegate = self
    
    }
    
}

extension LocationSearchTable: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        matchingItems = completer.results
        self.tableView.reloadData()
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("there was an error w/ the MKLocalSearchCompleter \(error)")
    }
}


// MARK: - Table View methods
extension LocationSearchTable {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "locationCell")!
        let searchResult = matchingItems[indexPath.row]
        cell.textLabel?.text = searchResult.title
        cell.detailTextLabel?.text = searchResult.subtitle
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItem = matchingItems[indexPath.row]
        let searchRequest = MKLocalSearchRequest(completion: selectedItem)
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, error) in
            if error != nil { print("error when tapping \(selectedItem.title): \(error)") }
            if selectedItem.subtitle == "" { // if this is a suggestion (not an address)
                guard let items = response?.mapItems else { return }
                self.handleMapSearchDelegate?.dropPins(for: items.map { return $0.placemark } ) // convert the MKMapItems to MKPlacemarks
            } else { // this is an address
                if let placemark = response?.mapItems[0].placemark {
                    self.handleMapSearchDelegate?.dropPin(for: placemark, saveToLocations: true)
                }
            }
        }
        dismiss(animated: true, completion: nil)
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.handleMapSearchDelegate?.didScroll()
    }
    
    

}
