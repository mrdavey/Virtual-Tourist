//
//  Photo.swift
//  Virtual Tourist
//
//  Created by David Truong on 17/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Photo: NSManagedObject {
    
    @NSManaged var id: NSNumber
    @NSManaged var url_q: String
    @NSManaged var pin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        let tempID = dictionary["id"] as! String // Flickr API returns ID as String for some reason...
        id = Int(tempID)!
        url_q = dictionary["url_q"] as! String
    }
    
    var urlImage: UIImage? {
        get {
            return FlickrClient.Caches.imageCache.imageWithIdentifier(url_q)
        }
        
        set {
            FlickrClient.Caches.imageCache.storeImage(newValue, withIdentifier: url_q)
        }
    }
}