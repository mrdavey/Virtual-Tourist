//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by David Truong on 14/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {
    
    var temp = 0
    var sharedContext: NSManagedObjectContext { return CoreDataStackManager.sharedInstance().managedObjectContext }
    var pinAddedViaLongPress: Pin!
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        restoreMapRegion()
        self.mapView.addAnnotations(fetchAllObjects())
        
        self.mapView.delegate = self
    }
    
    @IBAction func userLongPressedMapView(sender: UILongPressGestureRecognizer) {
        let tapPoint = sender.locationInView(self.mapView)
        let tapPointCoordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: self.mapView)
        
        if sender.state == UIGestureRecognizerState.Began {
            pinAddedViaLongPress = Pin(annotationTitle: "Loading...", annotationLatitude: tapPointCoordinate.latitude, annotationLongitude: tapPointCoordinate.longitude, context: sharedContext)
            self.mapView.addAnnotation(pinAddedViaLongPress)
        } else if sender.state == UIGestureRecognizerState.Changed {
            pinAddedViaLongPress.coordinate = tapPointCoordinate
        } else if sender.state == UIGestureRecognizerState.Ended {
            pinAddedViaLongPress.coordinate = tapPointCoordinate
            reverseGeocodeLocation(tapPointCoordinate)
            CoreDataStackManager.sharedInstance().saveContext()
            self.mapView.selectAnnotation(pinAddedViaLongPress, animated: true)
            UIView.animateWithDuration(0.5) {
                self.mapView.centerCoordinate = self.pinAddedViaLongPress.coordinate
            }
            
        }
    }
    
    // Reverse Geocode location of pin drop
    func reverseGeocodeLocation(coordinate: CLLocationCoordinate2D) {
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { placemarks, error in
            
            if error != nil {
                print("Reverse Geocode Fail Error: \(error!.localizedDescription)")
                return
            }
            if placemarks?.count > 0 {
                let pm = placemarks![0]
                if let annotationTitle = pm.locality ?? pm.subLocality {
                    self.pinAddedViaLongPress.title = annotationTitle
                } else {
                    self.pinAddedViaLongPress.title = "Unknown place"
                }
            } else {
                self.pinAddedViaLongPress.title = "Unknown place"
            }
        }
    }
    
    
    // MARK: - Fetch allObjects and load pins
    func fetchAllObjects() -> [Pin] {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        do {
            return try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
        } catch let error as NSError {
            print("Error: \(error.localizedDescription)")
            return [Pin]()
        }
    }
    
    
    // MARK: - MapView Delegates
    
    // Annotations setup
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = UIColor.redColor()
            pinView!.rightCalloutAccessoryView = UIButton(type: UIButtonType.DetailDisclosure)
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // TODO: - fix URL open for subtitle
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == view.rightCalloutAccessoryView {
            let app  = UIApplication.sharedApplication()
            if let subtitle = view.annotation!.subtitle! {
                app.openURL(NSURL(string: subtitle)!)
            }
        }
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    func saveMapRegion() {
        let mapRegion = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        NSUserDefaults.standardUserDefaults().setObject(mapRegion, forKey: "mapRegion")
    }
    
    func restoreMapRegion() {
        if let mapRegion = NSUserDefaults.standardUserDefaults().objectForKey("mapRegion") {
            
            let longitude = mapRegion["longitude"] as! CLLocationDegrees
            let latitude = mapRegion["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = mapRegion["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = mapRegion["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            self.mapView.setRegion(savedRegion, animated: false)
        }
    }
}
