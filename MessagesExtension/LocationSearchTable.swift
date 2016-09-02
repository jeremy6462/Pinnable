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

    weak var pullUpController: ISHPullUpViewController!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        resultSearchController = UISearchController(searchResultsController: self)
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

extension LocationSearchTable: ISHPullUpSizingDelegate, ISHPullUpStateDelegate {
    
    // Sizing
    
    func pullUpViewController(_ pullUpViewController: ISHPullUpViewController, minimumHeightForBottomViewController bottomVC: UIViewController) -> CGFloat {
        print("bottom layout guide =  \(self.bottomLayoutGuide)")
        return 100
    }
    
    func pullUpViewController(_ pullUpViewController: ISHPullUpViewController, maximumHeightForBottomViewController bottomVC: UIViewController, maximumAvailableHeight: CGFloat) -> CGFloat {
        print("Top = \(UIScreen.main.bounds.height)")
        return UIScreen.main.bounds.height - 100
    }
    
    func pullUpViewController(_ pullUpViewController: ISHPullUpViewController, targetHeightForBottomViewController bottomVC: UIViewController, fromCurrentHeight height: CGFloat) -> CGFloat {
        return UIScreen.main.bounds.height / 3
    }
    
    func pullUpViewController(_ pullUpViewController: ISHPullUpViewController, update edgeInsets: UIEdgeInsets, forBottomViewController contentVC: UIViewController) {
        tableView.contentInset = edgeInsets
    }
    
    // State
    
    func pullUpViewController(_ pullUpViewController: ISHPullUpViewController, didChangeTo state: ISHPullUpState) {
        // TODO - draw the handle view
        
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
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.mapSearchDelegate?.clear()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.mapSearchDelegate?.clear()
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
                    self.mapSearchDelegate?.dropPin(for: placemark, saveToLocations: true)
                }
            }
        }
        dismiss(animated: true, completion: nil)
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.resultSearchController?.searchBar.resignFirstResponder()
    }

}
