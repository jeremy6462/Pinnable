//
//  LocationSearchTable.swift
//  Map
//
//  Created by Jeremy Kelleher on 7/13/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import UIKit
import MapKit

// TODO - rename to MapSearcher

class LocationSearchTable : UITableViewController {
    
    var resultSearchController: UISearchController? = nil
    
    var matchingItems:[MKLocalSearchCompletion] = []
    var mapView: MKMapView? = nil
    
    var mapSearchDelegate:MapSearchDelegate? = nil
    
    override func viewDidLoad() {
        resultSearchController = UISearchController(searchResultsController: nil)
        resultSearchController?.searchResultsUpdater = self
        
        let searchBar = resultSearchController!.searchBar
        searchBar.delegate = self
        searchBar.placeholder = "Search for places to pin"
        tableView.tableHeaderView = searchBar
        searchBar.sizeToFit()
        
        resultSearchController?.hidesNavigationBarDuringPresentation = true
        resultSearchController?.dimsBackgroundDuringPresentation = false // make the map view still usable after the search button is pressed!
    }

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

extension LocationSearchTable: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.mapSearchDelegate?.search()
        self.dismiss(animated: true, completion: nil)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.mapSearchDelegate?.clear()
        self.dismiss(animated: true, completion: nil)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.mapSearchDelegate?.clear()
        self.dismiss(animated: true, completion: nil)
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
                self.mapSearchDelegate?.dropPins(for: items.map { return $0.placemark } ) // convert the MKMapItems to MKPlacemarks
            } else { // this is an address
                if let placemark = response?.mapItems[0].placemark {
                    self.mapSearchDelegate?.dropPin(for: placemark, saveToLocations: true, dismissPresentedVC: true)
                }
            }
        }
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.resultSearchController?.searchBar.resignFirstResponder()
    }

}
