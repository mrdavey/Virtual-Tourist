//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by David Truong on 17/10/2015.
//  Copyright © 2015 David Truong. All rights reserved.
//

import Foundation

class FlickrClient: NSObject {
    let session: NSURLSession
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    func getImageFromFlickrBySearch(latitude: Double, longitude: Double, completionHandler: (result: AnyObject?, error: String?) -> Void) {
        print("flickr search")
        let methodArguments = [
            "method": FlickrClient.Constants.METHOD_NAME,
            "api_key": FlickrClient.Constants.API_KEY,
            "bbox": createBoundingBoxString(latitude: latitude, longitude: longitude),
            "safe_search": FlickrClient.Constants.SAFE_SEARCH,
            "extras": FlickrClient.Constants.EXTRAS,
            "format": FlickrClient.Constants.DATA_FORMAT,
            "nojsoncallback": FlickrClient.Constants.NO_JSON_CALLBACK,
            "per_page": FlickrClient.Constants.PERPAGE,
            "sort": FlickrClient.Constants.SORT
        ]
        
        let urlString = FlickrClient.Constants.BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                let errorMessage = "There was an error with your request: \(error)"
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                var errorMessage: String
                if let response = response as? NSHTTPURLResponse {
                    errorMessage = "Your request returned an invalid response! Status code: \(response.statusCode)!"
                } else if let response = response {
                    errorMessage = "Your request returned an invalid response! Response: \(response)!"
                } else {
                    errorMessage = "Your request returned an invalid response!"
                }
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                let errorMessage = "No data was returned by the request!"
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                parsedResult = nil
                let errorMessage = "Could not parse the data as JSON: '\(data)'"
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* GUARD: Did Flickr return an error? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                let errorMessage = "Flickr API returned an error. See error code and message in \(parsedResult)"
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                let errorMessage = "Cannot find keys 'photos' in \(parsedResult)"
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary["pages"] as? Int else {
                let errorMessage = "Cannot find key 'pages' in \(photosDictionary)"
                completionHandler(result: nil, error: errorMessage)
                return
            }
            
            /* Pick a random page! */
            let pageLimit = min(totalPages, 40) // Flickr API returns max of 4000 results
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            FlickrClient.sharedInstance().getImagesFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage, completionHandler: completionHandler)
        }
        
        task.resume()
    }
    
    func getImagesFromFlickrBySearchWithPage(methodArguments: [String: AnyObject], pageNumber: Int, completionHandler: (result: AnyObject?, error: String?) -> Void) {

        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let urlString = FlickrClient.Constants.BASE_URL + escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                let error = "There was an error with your request: \(error!.localizedDescription)"
                completionHandler(result: nil, error: error)
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                if let response = response as? NSHTTPURLResponse {
                    let error = "Your request returned an invalid response! Status code: \(response.statusCode)!"
                    completionHandler(result: nil, error: error)
                } else if let response = response {
                    let error = "Your request returned an invalid response! Response: \(response)!"
                    completionHandler(result: nil, error: error)
                } else {
                    let error = "Your request returned an invalid response!"
                    completionHandler(result: nil, error: error)
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                let error = "No data was returned by the request!"
                completionHandler(result: nil, error: error)
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                parsedResult = nil
                let error = "Could not parse the data as JSON: '\(data)'"
                completionHandler(result: nil, error: error)
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                let error = "Flickr API returned an error. See error code and message in \(parsedResult)"
                completionHandler(result: nil, error: error)
                return
            }
            
            /* GUARD: Is the "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                let error = "Cannot find key 'photos' in \(parsedResult)"
                completionHandler(result: nil, error: error)
                return
            }
            
            /* GUARD: Is the "total" key in photosDictionary? */
            guard let totalPhotosVal = (photosDictionary["total"] as? NSString)?.integerValue else {
                let error = "Cannot find key 'total' in \(photosDictionary)"
                completionHandler(result: nil, error: error)
                return
            }
            
            if totalPhotosVal > 0 {
                completionHandler(result: photosDictionary, error: nil)
            } else if totalPhotosVal == 0 {
                completionHandler(result: nil, error: nil)
            }
        }
        task.resume()
    }
    
    func createBoundingBoxString(latitude latitude: Double, longitude: Double) -> String {
        /* Bounding box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - FlickrClient.Constants.BOUNDING_BOX_HALF_WIDTH, FlickrClient.Constants.LON_MIN)
        let bottom_left_lat = max(latitude - FlickrClient.Constants.BOUNDING_BOX_HALF_HEIGHT, FlickrClient.Constants.LAT_MIN)
        let top_right_lon = min(longitude + FlickrClient.Constants.BOUNDING_BOX_HALF_HEIGHT, FlickrClient.Constants.LON_MAX)
        let top_right_lat = min(latitude + FlickrClient.Constants.BOUNDING_BOX_HALF_HEIGHT, FlickrClient.Constants.LAT_MAX)
        print("\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)")
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    func taskForImage(url: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        let request = NSURLRequest(URL: NSURL(string: url)!)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                completionHandler(imageData: nil, error: error)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        
        return task
    }
    
    // MARK: Escape HTML Parameters
    
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        for (key, value) in parameters {
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    // MARK: - Shared Image Cache
    
    struct Caches {
        static let imageCache = ImageCache()
    }
    
    // MARK: - Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
}