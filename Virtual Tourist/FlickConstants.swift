//
//  FlickConstants.swift
//  Virtual Tourist
//
//  Created by David Truong on 17/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import Foundation

extension FlickrClient {
    
    struct Constants {
        static let BASE_URL = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME = "flickr.photos.search"
        static let API_KEY = "05748f2b08d3ada8236da548131c5a96"
        
        static let EXTRAS = "url_q"
        static let PERPAGE = "100" // Max out at 100 for now..
        static let PAGE = "1" // first page for now...
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK = "1"
        
        // 1 Degree of latitude/longitude ~ 111.2 km
        // 0.009 degree of lat/long ~ 1 km
        static let BOUNDING_BOX_HALF_WIDTH = 0.0001
        static let BOUNDING_BOX_HALF_HEIGHT = 0.0001
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0
    }
}

