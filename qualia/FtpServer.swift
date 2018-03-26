//
//  FtpServer.swift
//  qualia
//
//  Created by Kirk Roerig on 3/25/18.
//  Copyright © 2018 Kirk Roerig. All rights reserved.
//

import UIKit
import CFNetwork


import Foundation
import CFNetwork

public class FtpServer : NSCoding {
    fileprivate let ftpBaseUrl: String
    fileprivate let directoryPath: String
    fileprivate let username: String
    fileprivate let password: String
    
    public init(baseUrl: String, userName: String, password: String, directoryPath: String) {
        self.ftpBaseUrl = baseUrl
        self.username = userName
        self.password = password
        self.directoryPath = directoryPath
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(ftpBaseUrl, forKey: "ftpBaseUrl");
        aCoder.encode(directoryPath, forKey: "directoryPath");
        aCoder.encode(password, forKey: "password");
        aCoder.encode(username, forKey: "username");
    }
    
    public required init?(coder aDecoder: NSCoder) {
        ftpBaseUrl = aDecoder.decodeObject(forKey: "ftpBaseUrl") as! String;
        directoryPath = aDecoder.decodeObject(forKey: "directoryPath") as! String;
        username = aDecoder.decodeObject(forKey: "username") as! String;
        password = aDecoder.decodeObject(forKey: "password") as! String;
    }
}


// MARK: - Steam Setup
extension FtpServer {
    private func setFtpUserName(for ftpWriteStream: CFWriteStream, userName: CFString) {
        let propertyKey = CFStreamPropertyKey(rawValue: kCFStreamPropertyFTPUserName)
        CFWriteStreamSetProperty(ftpWriteStream, propertyKey, userName)
    }
    
    private func setFtpPassword(for ftpWriteStream: CFWriteStream, password: CFString) {
        let propertyKey = CFStreamPropertyKey(rawValue: kCFStreamPropertyFTPPassword)
        CFWriteStreamSetProperty(ftpWriteStream, propertyKey, password)
    }
    
    fileprivate func ftpWriteStream(forFileName fileName: String) -> CFWriteStream? {
        let fullyQualifiedPath = "ftp://\(ftpBaseUrl)/\(directoryPath)/\(fileName)"
        
        guard let ftpUrl = CFURLCreateWithString(kCFAllocatorDefault, fullyQualifiedPath as CFString, nil) else { return nil }
        let ftpStream = CFWriteStreamCreateWithFTPURL(kCFAllocatorDefault, ftpUrl)
        let ftpWriteStream = ftpStream.takeRetainedValue()
        setFtpUserName(for: ftpWriteStream, userName: username as CFString)
        setFtpPassword(for: ftpWriteStream, password: password as CFString)
        return ftpWriteStream
    }
}


// MARK: - FTP Write
extension FtpServer {
    public func send(data: Data, with fileName: String, success: @escaping ((Bool)->Void)) {
        
        guard let ftpWriteStream = ftpWriteStream(forFileName: fileName) else {
            success(false)
            return
        }
        
        if CFWriteStreamOpen(ftpWriteStream) == false {
            print("Could not open stream")
            success(false)
            return
        }
        
        let fileSize = data.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: fileSize)
        data.copyBytes(to: buffer, count: fileSize)
        
        defer {
            CFWriteStreamClose(ftpWriteStream)
            buffer.deallocate(capacity: fileSize)
        }
        
        var offset: Int = 0
        var dataToSendSize: Int = fileSize
        
        repeat {
            let bytesWritten = CFWriteStreamWrite(ftpWriteStream, &buffer[offset], dataToSendSize)
            if bytesWritten > 0 {
                offset += bytesWritten.littleEndian
                dataToSendSize -= bytesWritten
                continue
            } else if bytesWritten < 0 {
                // ERROR
                print("FTPUpload - ERROR")
                break
            } else if bytesWritten == 0 {
                // SUCCESS
                print("FTPUpload - Completed!!")
                break
            }
        } while CFWriteStreamCanAcceptBytes(ftpWriteStream)
        
        success(true)
    }
}
