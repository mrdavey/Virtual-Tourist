//
//  Pin.swift
//  Virtual Tourist
//
//  Created by David Truong on 14/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Pin: NSManagedObject, MKAnnotation {
    
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var photos: [Photo]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(annotationLatitude: Double, annotationLongitude: Double, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
       
        latitude = annotationLatitude
        longitude = annotationLongitude
        
    }
    
    dynamic var coordinate: CLLocationCoordinate2D {
        set {
            longitude = newValue.longitude
            latitude = newValue.latitude
        }

        get { return CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }
}