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

private let reuseIdentifier = "Cell"

class PhotosCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {

    // Keep track of the 'selected' photos
    var selectedIndexes = [NSIndexPath]()
    
    // Keep track of changes made on photos
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    var pin: Pin!
    var restoreMapRegion: MapRegion!
    var numberOfPhotos: Int!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noImagesLabel: UILabel!
    @IBOutlet weak var bottomButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start the fetched results controller
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Error performing initial fetch: \(error.localizedDescription)")
        }
        
        fetchedResultsController.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        self.mapView.addAnnotation(pin)
        self.restoreExistingMapRegion()
        networkActivityIndicator()
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
        collectionView.collectionViewLayout = layout
    }
    
    func BtnTapBack(sender: UIButton) {
        navigationController?.popViewControllerAnimated(true)
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
        
        print("in controllerWillChangeContent")
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
        
        print("in controllerDidChangeContent. changes.count: \(insertedIndexPaths.count + deletedIndexPaths.count)")
        
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            self.networkActivityIndicator()
        }
    }
    
    // FetchedResultsController related
    
    @IBAction func bottomButtonTapped(sender: UIBarButtonItem) {
        if selectedIndexes.isEmpty {
            deleteAllPhotos()
            print("all photos deleted")
            reloadPhotos()
            dispatch_async(dispatch_get_main_queue()) {
                self.networkActivityIndicator()
            }
            self.collectionView.reloadData()
        } else {
            deleteSelectedPhotos()
        }
        saveContext()
        self.collectionView.reloadData()
    }
    
    func reloadPhotos() {
        print("reloadPhotos")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        FlickrClient.sharedInstance().getImagesFromFlickrBySearch(pin.latitude, longitude: pin.longitude) { result, error in
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
                    print("more than 0 photos found")
                    self.numberOfPhotos = photosDictionary.count
                    var photoCount = 1
                    let _ = photosDictionary.map() { (dictionary: [String: AnyObject]) -> Photo in
                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                        let imageData = NSData(contentsOfURL: NSURL(string: photo.url_q)!)
                        photo.urlImage = UIImage(data: imageData!)
                        photo.pin = self.pin
                        print("photoCount: \(photoCount++), numberOfPhotos: \(self.numberOfPhotos)")
                        return photo
                    }
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                } else {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    // TODO: - error message
                    print("Error parsing photos result \(result)")
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.networkActivityIndicator()
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
        for photo in fetchedResultsController.fetchedObjects as! [Photo] {
            sharedContext.deleteObject(photo)
        }
        saveContext()
    }
    
    func deleteSelectedPhotos() {
        var photosToDelete = [Photo]()
        
        for indexPath in selectedIndexes {
            photosToDelete.append(fetchedResultsController.objectAtIndexPath(indexPath) as! Photo)
        }
        
        for photo in photosToDelete {
            sharedContext.deleteObject(photo)
        }
        
        selectedIndexes = [NSIndexPath]()
    }
    
    func updateBottomButton() {
        if selectedIndexes.count > 0 {
            bottomButton.title = "Remove Selected Photos"
        } else {
            bottomButton.title = "New Collection"
        }
    }
    
    func networkActivityIndicator() {
        if UIApplication.sharedApplication().networkActivityIndicatorVisible == true {
            self.bottomButton.title = ""
            self.bottomButton.enabled = false
            self.activityIndicator.startAnimating()
        } else {
            self.bottomButton.title = "New Collection"
            self.bottomButton.enabled = true
            self.activityIndicator.stopAnimating()
        }
    }
    
    // MARK: - Core Data Convenience
    
    lazy var sharedContext: NSManagedObjectContext =  {
        return CoreDataStackManager.sharedInstance().managedObjectContext
        }()
    
    func saveContext() {
        CoreDataStackManager.sharedInstance().saveContext()
    }
    

    // MARK: UICollectionViewDataSource

    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        let count = sectionInfo.numberOfObjects
        
        if count == 0 {
            self.noImagesLabel.hidden = false
        } else {
            self.noImagesLabel.hidden = true
        }
        
        return count
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
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        var photoImage = UIImage(named: "defaultImage")!
        
        if photo.urlImage == nil {
            _ = FlickrClient.sharedInstance().taskForImage(photo.url_q) { data, error in
                if let error = error {
                    print("Image download error: \(error.localizedDescription)")
                }
                
                if let data = data {
                    // Create the image
                    let image = UIImage(data: data)
                    
                    // update the model, so that the information gets cached
                    photo.urlImage = image
                    
                    // update the cell later, on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.imageView!.image = image
                    }
                }
            }
        } else {
            photoImage = photo.urlImage!
        }
        
        cell.imageView.image = photoImage
            
        
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
