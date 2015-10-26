//
//  PhotosCollectionViewController.swift
//  Virtual Tourist
//
//  Created by David Truong on 16/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import UIKit
import MapKit
import CoreData

protocol PhotosCollectionViewControllerDelegate {
    func reloadPhoto()
}


private let reuseIdentifier = "Cell"

class PhotosCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {
    
    var privateQueueContext: NSManagedObjectContext { return CoreDataStackManager.sharedInstance.privateQueueContext }
    
    // Keep track of the 'selected' photos
    var selectedIndexes = [NSIndexPath]()
    
    // Keep track of changes made on photos
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    var pin: Pin! {
        didSet {
            CoreDataStackManager.sharedInstance.saveContext()
            print("ObjectID didSet: \(self.pin.objectID)")
        }
    }
    var pinPrivateQueue: Pin!
    var restoreMapRegion: MapRegion!
    var numberOfPhotos: Int!
    var preFetchedPhotos: Bool!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noImagesLabel: UILabel!
    @IBOutlet weak var bottomButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchedResultsController.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        self.performFetch()
        self.mapView.addAnnotation(pin)
        self.restoreExistingMapRegion()
        networkActivityIndicator()
        
        if let fetchedObjects = self.fetchedResultsController.fetchedObjects?.count {
            print("fetchedObjects.count: \(fetchedObjects)")
            if preFetchedPhotos == false  && fetchedObjects == 0 {
                print("Need to fetch and download images")
                self.reloadPhotos()
            } else if preFetchedPhotos == false && fetchedObjects != 0 {
                print("Opening pin that has already downloaded photos")
                self.numberOfPhotos = self.fetchedResultsController.fetchedObjects!.count
            } else if preFetchedPhotos == true && fetchedObjects == 0 {
                print("prefetched true, fetchedObjects 0")
                self.collectionView.reloadData()
            }
        } else {
            print("fetchObjects is nil: \(self.fetchedResultsController.fetchedObjects?.count)")
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Lay out the collection view so that cells take up 1/3 of the width,
        // with no space in between.
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.collectionView.frame.size.width/3)
        layout.itemSize = CGSize(width: width, height: width)
        self.collectionView.collectionViewLayout = layout
    }
    
    func BtnTapBack(sender: UIButton) {
        navigationController?.popViewControllerAnimated(true)
    }
    
    func performFetch() {
        do {
            try fetchedResultsController.performFetch()
            print("fetchPerformed")
        } catch let error as NSError {
            print("Error performing initial fetch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - NSFetchedResultsController
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        return fetchedResultsController
        }()
    
    
    // MARK: - Fetched Results Controller Delegate
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
        
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type{
            
        case .Insert:
            print("Insert an item")
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            print("Delete an item")
            deletedIndexPaths.append(indexPath!)
            break
        case .Update:
            print("Update an item.")
            updatedIndexPaths.append(indexPath!)
            break
        case .Move:
            print("Move an item. We don't expect to see this in this app.")
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.collectionView.performBatchUpdates({() -> Void in
            
            if self.insertedIndexPaths.count > 0 {
                print("insert")
                for indexPath in self.insertedIndexPaths {
                    self.collectionView.insertItemsAtIndexPaths([indexPath])
                }
            }
            
            if self.deletedIndexPaths.count > 0 {
                print("delete \(self.deletedIndexPaths.count)")
                for indexPath in self.deletedIndexPaths {
                    self.collectionView.deleteItemsAtIndexPaths([indexPath])
                }
            }
            
            if self.updatedIndexPaths.count > 0 {
                print("update")
                for indexPath in self.updatedIndexPaths {
                    self.collectionView.reloadItemsAtIndexPaths([indexPath])
                }
            }
            
            }, completion: nil)
        self.collectionView.reloadData()
        print("fin")
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            self.networkActivityIndicator()
        }
    }
    
    // FetchedResultsController related
    
    @IBAction func bottomButtonTapped(sender: UIBarButtonItem) {
        self.sharedContext.performBlock(){
            if self.selectedIndexes.isEmpty {
                self.networkActivityIndicator()
                self.deleteAllPhotos()
                self.reloadPhotos()
            } else {
                self.deleteSelectedPhotos()
            }
            self.saveContext()
        }
    }
    
    func reloadPhotos() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        FlickrClient.sharedInstance.getImageFromFlickrBySearch(pin.latitude, longitude: pin.longitude) { result, error in
            print("getImagesFromFlickr")
            guard (error == nil) else {
                // TODO: - Show error
                print("Error occured \(error!)")
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                dispatch_async(dispatch_get_main_queue()) {
                    self.networkActivityIndicator()
                }
                return
            }
            
            if let photosDictionary = result?.valueForKey("photo") as? [[String : AnyObject]] {
                //Parse the dict
                if photosDictionary.count > 0 {
                    self.numberOfPhotos = photosDictionary.count
                    var photoCount = 1
                    print("\(self.numberOfPhotos) photos found")
                    
                    self.privateQueueContext.performBlock(){
                        do {
                            self.pinPrivateQueue = try self.privateQueueContext.existingObjectWithID(self.pin.objectID) as! Pin
                        } catch {
                            print("Error setting pinPrivateQueue: \(error)")
                        }
                        let _ = photosDictionary.map() { (dictionary: [String: AnyObject]) -> Photo in
                            let photo = Photo(dictionary: dictionary, context: self.privateQueueContext)
                            photo.pin = self.pinPrivateQueue
                            print("photoCount: \(photoCount++), numberOfPhotos: \(self.numberOfPhotos)")
                            return photo
                        }
                        CoreDataStackManager.sharedInstance.savePrivateContext()
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                            self.networkActivityIndicator()
                            self.performFetch()
                            self.collectionView.reloadData()
                        }
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    }
                } else {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    // TODO: - error message
                    print("Error parsing photos result \(result)")
                }
            } else {
                print("0 photos")
                // 0 photos
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                dispatch_async(dispatch_get_main_queue()) {
                    self.networkActivityIndicator()
                }
                self.numberOfPhotos = 0
            }
        }
    }
    
    func deleteAllPhotos() {
        for photo in self.fetchedResultsController.fetchedObjects as! [Photo] {
            self.sharedContext.deleteObject(photo)
        }
        numberOfPhotos = 0
    }
    
    func deleteSelectedPhotos() {
        var photosToDelete = [Photo]()
        
        for indexPath in selectedIndexes {
            photosToDelete.append(fetchedResultsController.objectAtIndexPath(indexPath) as! Photo)
        }
        
        selectedIndexes = [NSIndexPath]()
        
        for photo in photosToDelete {
            sharedContext.deleteObject(photo)
            numberOfPhotos = numberOfPhotos - 1
        }
    }
    
    func updateBottomButton() {
        if self.selectedIndexes.count > 0 {
            self.bottomButton.title = "Remove Selected Photos"
        } else {
            self.bottomButton.title = "New Collection"
        }
    }
    
    func networkActivityIndicator() {
        if UIApplication.sharedApplication().networkActivityIndicatorVisible == true {
            self.noImagesLabel.text = "Loading new images..."
            self.bottomButton.title = ""
            self.bottomButton.enabled = false
            self.activityIndicator.startAnimating()
        } else {
            self.noImagesLabel.text = "No Images"
            self.bottomButton.title = "New Collection"
            self.bottomButton.enabled = true
            self.activityIndicator.stopAnimating()
        }
    }
    
    // MARK: - Core Data Convenience
    
    lazy var sharedContext: NSManagedObjectContext =  {
        return CoreDataStackManager.sharedInstance.managedObjectContext
        }()
    
    func saveContext() {
        CoreDataStackManager.sharedInstance.saveContext()
    }
    
    
    // MARK: UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        let count = sectionInfo.numberOfObjects

        if count == 0 && numberOfPhotos == 0 {
            self.noImagesLabel.hidden = false
            return 0
        } else if count == 0 && numberOfPhotos > 0 {
            // Prefetched number of photos known, not yet saved to CoreData
            self.noImagesLabel.hidden = true
            return numberOfPhotos
        } else {
            self.noImagesLabel.hidden = true
            return count
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PhotosCollectionViewCell
        self.configureCell(cell, atIndexPath: indexPath)
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if self.bottomButton.enabled == true {
            let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotosCollectionViewCell
            
            // Whenever a cell is tapped we will toggle its presence in the selectedIndexes array
            if let index = selectedIndexes.indexOf(indexPath) {
                selectedIndexes.removeAtIndex(index)
            } else {
                selectedIndexes.append(indexPath)
            }
            
            // Then reconfigure the cell
            configureCell(cell, atIndexPath: indexPath)
            
            // And update the buttom button
            updateBottomButton()
        } else {
            print("Images downloading hasn't completed yet")
        }
    }
    
    func configureCell(cell: PhotosCollectionViewCell, atIndexPath indexPath: NSIndexPath) {
        cell.activityIndicator.stopAnimating()
        var photoImage = UIImage(named: "defaultImage")!
        let fetchResultsCount = self.fetchedResultsController.fetchedObjects!.count ?? 0
        
        self.sharedContext.performBlock() {
            if indexPath.row < self.numberOfPhotos && fetchResultsCount != 0 {
                let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
                if photo.urlImage == nil {
                    _ = FlickrClient.sharedInstance.taskForImage(photo.url_q) { data, error in
                        if let error = error {
                            print("Image download error: \(error.localizedDescription)")
                        }
                        if let data = data {
                            // Create the image
                            let image = UIImage(data: data)
                            
                            dispatch_async(dispatch_get_main_queue()) {
                                // update the model, so that the information gets cached
                                photo.urlImage = image
                                // update the cell later, on the main thread
                                cell.imageView!.image = image
                            }
                        }
                    }
                    
                } else {
                    photoImage = photo.urlImage!
                }
                self.saveContext()
            }
        }
        
        dispatch_async(dispatch_get_main_queue()){
            cell.imageView.image = photoImage
        }
        
        if let _ = selectedIndexes.indexOf(indexPath) {
            cell.imageView.alpha = 0.5
        } else {
            cell.imageView.alpha = 1.0
        }
    }
    
    func restoreExistingMapRegion() {
        let center = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let span = MKCoordinateSpan(latitudeDelta: restoreMapRegion.latDelta / 2, longitudeDelta: restoreMapRegion.longDelta / 2)
        let restoreRegion = MKCoordinateRegion(center: center, span: span)
        
        self.mapView.setRegion(restoreRegion, animated: false)
    }
    
}
