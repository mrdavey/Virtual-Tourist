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
    var tempContext: NSManagedObjectContext!
    
    var pinAddedViaLongPress: Pin!
    var pins: [Pin]?
    var tempPin: Pin!
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start the fetched results controller
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Error performing initial fetch: \(error.localizedDescription)")
        }
        
        self.pins = fetchAllObjects()
        self.mapView.addAnnotations(pins!)
        
        self.mapView.delegate = self
        fetchedResultsController.delegate = self
        restoreExistingMapRegion()
        
        

        tempContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
        tempContext.persistentStoreCoordinator = sharedContext.persistentStoreCoordinator
    }
    
    @IBAction func userLongPressedMapView(sender: UILongPressGestureRecognizer) {
        let tapPoint = sender.locationInView(self.mapView)
        let tapPointCoordinate = mapView.convertPoint(tapPoint, toCoordinateFromView: self.mapView)
        
        if sender.state == UIGestureRecognizerState.Began {
            tempPin = Pin(annotationLatitude: tapPointCoordinate.latitude, annotationLongitude: tapPointCoordinate.longitude, context: self.tempContext)
            self.mapView.addAnnotation(tempPin)
        } else if sender.state == UIGestureRecognizerState.Changed {
            tempPin.coordinate = tapPointCoordinate
        } else if sender.state == UIGestureRecognizerState.Ended {
            tempPin.coordinate = tapPointCoordinate
            UIView.animateWithDuration(0.5) {
                self.mapView.centerCoordinate = self.tempPin.coordinate
            }
            
            self.preFetchFlickerImages()
        }
    }
    
    // MARK: - Fetch data
    func preFetchFlickerImages() {
        print("Running preFetchFlickrImages")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        // Check if any photos in that location
        FlickrClient.sharedInstance().getImagesFromFlickrBySearch(tempPin.coordinate.latitude, longitude: tempPin.coordinate.longitude) { result, error in
            
            guard (error == nil) else {
                // TODO: - Show error
                dispatch_async(dispatch_get_main_queue()) {
                    self.mapView.removeAnnotation(self.tempPin)
                }
                print("Error occured \(error!)")
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                return
            }
            self.pinAddedViaLongPress = Pin(annotationLatitude: self.tempPin.coordinate.latitude, annotationLongitude: self.tempPin.coordinate.longitude, context: self.sharedContext)
            dispatch_async(dispatch_get_main_queue()) {
                self.mapView.addAnnotation(self.pinAddedViaLongPress)
                self.mapView.removeAnnotation(self.tempPin)
            }
            
            if let photosDictionary = result?.valueForKey("photo") as? [[String : AnyObject]] {
                //Parse the dict
                if photosDictionary.count > 0 {
                    print("PhotoDictionary Count: \(photosDictionary.count)")
                    var photoCount = 1
                    let _ = photosDictionary.map() { (dictionary: [String: AnyObject]) -> Photo in
                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                        
                        let imageData = NSData(contentsOfURL: NSURL(string: photo.url_q)!)
                        photo.urlImage = UIImage(data: imageData!)
                        photo.pin = self.pinAddedViaLongPress
                        print("photoCount: \(photoCount++)")
                        return photo
                    }
                    CoreDataStackManager.sharedInstance().saveContext()
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
        controller.restoreMapRegion = fetchExistingMapRegion()
        controller.numberOfPhotos = selectedPin.photos.count
        
        print("MapVC, selectedPin photoCount: \(selectedPin.photos.count)")
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
        
        print("ExistingMapRegion: \(existingMapRegion)")
        let center = CLLocationCoordinate2D(latitude: existingMapRegion.lat, longitude: existingMapRegion.long)
        let span = MKCoordinateSpan(latitudeDelta: existingMapRegion.latDelta, longitudeDelta: existingMapRegion.longDelta)
        let restoreRegion = MKCoordinateRegion(center: center, span: span)
        
        self.mapView.setRegion(restoreRegion, animated: false)
    }
}
