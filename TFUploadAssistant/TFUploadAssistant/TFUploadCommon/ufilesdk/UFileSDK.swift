//
//  UFileSDK.swift
//  ufile sdk demo
//
//  Created by wu shauk on 12/14/15.
//  Copyright © 2015 ucloud. All rights reserved.
//

import Foundation

class UFileSDK : NSObject {
    
    var ufileSDK: UFileAPI?
    var bucket: String?
    var publicKey: String?
    var privateKey: String?
    
    init(fromKeys publicKey: String, privateKey: String, bucket: String) {
        self.ufileSDK = UFileAPI(bucket:bucket, url:"http://ufile.ucloud.cn")
        self.bucket = bucket;
        self.publicKey = publicKey;
        self.privateKey = privateKey;
    }
    
    func calcKey(httpMethod: String, key: String, contentMd5: String?, contentType: String?) -> String {
        var s = httpMethod + "\n";
        if let type = contentMd5 {
            s += type;
        }
        s += "\n";
        if let md5s = contentType {
            s += md5s;
        }
        s += "\n";
        // date
        s += "\n";
        // ucloud header
        s += "";
        s += "/" + self.bucket! + "/" + key;
        return self._sha1Sum(self.privateKey!, s: s)
    }
    
    private func _sha1Sum(key: String, s: String) -> String {
        let str = s.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = Int(s.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = Int(CC_SHA1_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        let keyStr = key.cStringUsingEncoding(NSUTF8StringEncoding)
        let keyLen = Int(key.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyStr!, keyLen, str!, strLen, result)
        
        let digest = stringFromResult(result, length: digestLen)
        
        result.dealloc(digestLen)
        
        return "UCloud " + self.publicKey! + ":" + digest;
    }
    
    private func stringFromResult(result: UnsafeMutablePointer<CUnsignedChar>, length: Int) -> String {
        let hash = NSData(bytes: result, length: length);
        return hash.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }
}
