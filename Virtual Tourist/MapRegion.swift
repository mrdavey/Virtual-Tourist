//
//  MapRegion.swift
//  Virtual Tourist
//
//  Created by David Truong on 19/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import Foundation
import CoreData

class MapRegion: NSManagedObject {
    @NSManaged var long: Double
    @NSManaged var lat: Double
    @NSManaged var longDelta: Double
    @NSManaged var latDelta: Double
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(mapRegion: [String : Double], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("MapRegion", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        lat = mapRegion["latitude"]!
        long = mapRegion["longitude"]!
        latDelta = mapRegion["latitudeDelta"]!
        longDelta = mapRegion["longitudeDelta"]!
    }
}