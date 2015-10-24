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

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    var sharedContext: NSManagedObjectContext { return CoreDataStackManager.sharedInstance().managedObjectContext }
    var privateQueueContext: NSManagedObjectContext { return CoreDataStackManager.sharedInstance().privateQueueContext }
    var tempPinContext: NSManagedObjectContext!
    
    var pinAddedViaLongPress: Pin! {
        didSet {
            CoreDataStackManager.sharedInstance().saveContext()
            print("ObjectID didSet: \(self.pinAddedViaLongPress.objectID)")
        }
    }
    var privatePinAdded: Pin!
    var pins: [Pin]?
    var tempPin: Pin!
    var numberOfPhotos: Int?
    var preFetchCompleted: Bool = false
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start the fetched results controller
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Error performing initial fetch: \(error.localizedDescription)")
        }
        
        self.pins = self.fetchAllObjects()
        self.mapView.addAnnotations(self.pins!)
        
        self.mapView.delegate = self
        self.fetchedResultsController.delegate = self
        self.restoreExistingMapRegion()
        
        tempPinContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        tempPinContext.persistentStoreCoordinator = sharedContext.persistentStoreCoordinator
        
    }
    
    override func viewDidAppear(animated: Bool) {
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    @IBAction func userLongPressedMapView(sender: UILongPressGestureRecognizer) {
        let tapPoint = sender.locationInView(self.mapView)
        let tapPointCoordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: self.mapView)
        
        if sender.state == UIGestureRecognizerState.Began {
            self.tempPin = Pin(annotationLatitude: tapPointCoordinate.latitude, annotationLongitude: tapPointCoordinate.longitude, context: self.tempPinContext)
            self.mapView.addAnnotation(self.tempPin)
        } else if sender.state == UIGestureRecognizerState.Changed {
            self.tempPin.coordinate = tapPointCoordinate
        } else if sender.state == UIGestureRecognizerState.Ended {
            self.tempPin.coordinate = tapPointCoordinate
            UIView.animateWithDuration(0.5) {
                self.mapView.centerCoordinate = self.tempPin.coordinate
            }
            self.preFetchFlickerImages()
            CoreDataStackManager.sharedInstance().saveContext()
        }
        
    }
    
    // MARK: - Fetch data
    
    func preFetchFlickerImages() {
        print("Running preFetchFlickrImages")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        // Check if any photos in that location
        FlickrClient.sharedInstance().getImageFromFlickrBySearch(tempPin.coordinate.latitude, longitude: tempPin.coordinate.longitude) { result, error in
            
            guard (error == nil) else {
                // TODO: - Show error
                dispatch_async(dispatch_get_main_queue()) {
                    self.mapView.removeAnnotation(self.tempPin)
                }
                print("Error occured \(error!)")
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                return
            }
            
            self.sharedContext.performBlockAndWait() {
                self.pinAddedViaLongPress = Pin(annotationLatitude: self.tempPin.coordinate.latitude, annotationLongitude: self.tempPin.coordinate.longitude, context: self.sharedContext)
                print("created Pin")
                self.mapView.removeAnnotation(self.tempPin)
                self.mapView.addAnnotation(self.pinAddedViaLongPress)
                CoreDataStackManager.sharedInstance().saveContext()
            }
            
            if let photosDictionary = result?.valueForKey("photo") as? [[String : AnyObject]] {
                self.numberOfPhotos = photosDictionary.count
                //Parse the dict
                if photosDictionary.count > 0 {
                    self.privateQueueContext.performBlockAndWait() {
                        do {
                            self.privatePinAdded = try self.privateQueueContext.existingObjectWithID(self.pinAddedViaLongPress.objectID) as! Pin
                        } catch {
                            print("Error setting privatePin: \(error)")
                            dispatch_async(dispatch_get_main_queue()) {
                                self.mapView.removeAnnotation(self.tempPin)
                            }
                            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                            return
                        }
                        let _ = photosDictionary.map() { (dictionary: [String: AnyObject]) -> Photo in
                            let photo = Photo(dictionary: dictionary, context: self.privateQueueContext)
                            photo.pin = self.privatePinAdded
                            return photo
                        }
                        CoreDataStackManager.sharedInstance().savePrivateContext()
                        self.preFetchCompleted = true
                    }
                }
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            } else {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                // TODO: - error message
                print("0 photos returned")
            }
        }
    }
    
    func fetchAllObjects() -> [Pin] {
        guard (fetchedResultsController.fetchedObjects != nil) else {
            print("nil objects in fetchedResultsController")
            return [Pin]()
        }
        return fetchedResultsController.fetchedObjects as! [Pin]
    }
    
    func fetchExistingMapRegion() -> MapRegion {
        let mapRegion = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        let fetchRequest = NSFetchRequest(entityName: "MapRegion")
        do {
            if let alreadyExistingMapRegion = try sharedContext.executeFetchRequest(fetchRequest).first as? MapRegion {
                return alreadyExistingMapRegion
            } else {
                print("creating region")
                return MapRegion(mapRegion: mapRegion, context: sharedContext)
            }
        } catch let error as NSError {
            print("Error fetching mapRegion: \(error.localizedDescription).")
            return MapRegion(mapRegion: mapRegion, context: sharedContext)
        }
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = []
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
        }()
    
    
    // MARK: - MapView Delegates
    
    // Annotations setup
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = UIColor.redColor()
        } else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        self.mapView.deselectAnnotation(view.annotation, animated: false)
        
        let controller = storyboard!.instantiateViewControllerWithIdentifier("PhotosCollectionViewController") as! PhotosCollectionViewController
        
        let selectedPin = view.annotation as! Pin
        controller.pin = selectedPin
        controller.restoreMapRegion = self.fetchExistingMapRegion()
        
        if let photosDownloaded = numberOfPhotos {
            controller.numberOfPhotos = photosDownloaded
        } else {
            controller.numberOfPhotos = controller.pin.photos.count
        }
        
        if preFetchCompleted == true {
            controller.preFetchedPhotos = true
        } else {
            controller.preFetchedPhotos = false
        }
        
        print("Selecting annotation view")
        self.navigationController!.pushViewController(controller, animated: true)
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let fetchRequest = NSFetchRequest(entityName: "MapRegion")
        do {
            let fetchedEntity = try sharedContext.executeFetchRequest(fetchRequest) as! [MapRegion]
            fetchedEntity.first?.lat = mapView.region.center.latitude
            fetchedEntity.first?.long = mapView.region.center.longitude
            fetchedEntity.first?.latDelta = mapView.region.span.latitudeDelta
            fetchedEntity.first?.longDelta = mapView.region.span.longitudeDelta
            CoreDataStackManager.sharedInstance().saveContext()
        } catch let error as NSError {
            print("Error fetching mapRegion on regionDidChangeAnimated: \(error.localizedDescription)")
        }
    }
    
    func restoreExistingMapRegion() {
        let existingMapRegion = fetchExistingMapRegion()
        let center = CLLocationCoordinate2D(latitude: existingMapRegion.lat, longitude: existingMapRegion.long)
        let span = MKCoordinateSpan(latitudeDelta: existingMapRegion.latDelta, longitudeDelta: existingMapRegion.longDelta)
        let restoreRegion = MKCoordinateRegion(center: center, span: span)
        
        self.mapView.setRegion(restoreRegion, animated: false)
    }
}
