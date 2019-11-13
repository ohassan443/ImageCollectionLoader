//
//  ImageLoaderServer.swift
//  Zabatnee
//
//  Created by Omar Hassan  on 1/30/19.
//  Copyright © 2019 Omar Hassan. All rights reserved.
//

import Foundation
import UIKit


class ImageLoader : ImageLoaderObj{
 
    
    
    private var  diskCache: DiskCacheProtocol
    private var ramCache: RamCacheProtocol
    
    init(diskCache:DiskCacheProtocol,ramCache:RamCacheProtocol) {
        self.ramCache = ramCache
        self.diskCache = diskCache
    }
    
    
    func queryRamCacheFor(url: String, result: @escaping (UIImage?) -> ()) {
        ramCache.getImageFor(url: url, result: result)
     }
    
    
    
    private func cacheToRam(image:UIImage,url:String)-> Void{
        ramCache.cache(image: image, url: url, result: {_ in})
    }
    
    
    
    /**
     try to read the image from the ram cache and if not founc check in the disk cache and if not found call the server  then save the loaded image to ram and disk caches for future use
     */
    func getImageFrom(urlString:String, completion:  @escaping (_ : UIImage)-> (),fail : @escaping (_ url:String,_ error:Error)-> ()) -> Void {
        
        
        DispatchQueue.global().async {
            [weak self] in
            guard let imageLoader = self else {return}
            
            
            imageLoader.ramCache.getImageFor(url: urlString, result: {
                ramImage in
                if let image = ramImage {
                    DispatchQueue.main.async {
                        completion(image)
                    }
                    return
                }
                
                imageLoader.diskCache.getImageFor(url: urlString, completion: {
                    diskCacheImage in
                    
                    if let image = diskCacheImage {
                        let _ = imageLoader.cacheToRam(image: image, url: urlString)
                        DispatchQueue.main.async {
                            completion(image)
                        }
                        return
                    }
                    
                    imageLoader.loadFromServer(urlString: urlString, completion: completion, fail: fail)
                })
                
            })
        }
    }
    
    
    
    
    private func loadFromServer(urlString:String, completion:  @escaping (_ : UIImage)-> (),fail : @escaping (_ url:String,_ error:Error)-> ()) -> Void {
        
        guard let url = URL(string: urlString) else{return}
        DispatchQueue.global().async {
            let session = imageLoaderUrlSession.getSession()
            
            session.dataTask(with: url, completionHandler: { [weak self](data, response, error) -> Void in
                guard let self = self else {return}
             
                    guard error == nil  else {
                        fail(urlString,error!)
                        return
                    }
                    
                    guard let data = data else{
                        fail(urlString,imageLoadingError.nilData)
                        return
                    }
                    guard let resultImage = UIImage(data: data) else {
                        fail(urlString,imageLoadingError.imageParsingFailed)
                        return
                    }
                    
                    let _ = self.cacheToRam(image: resultImage, url: urlString)
                    self.diskCache.cache(image: resultImage, url: urlString, completion: {_ in})
                
                DispatchQueue.main.async { [weak self] in
                    guard let _ = self else {return}
                    completion(resultImage)
                }
                
            }).resume()
            
        }
        
    }
    
    
}
