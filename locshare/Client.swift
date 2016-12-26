//
//  Client.swift
//  locshare
//
//  Created by Kenny Levinsen on 26/11/2016.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import Foundation

var GlobalClient = Client()

class Client {
    var url = ""

    func push(username: String, message: Data, finished: @escaping (Int) -> ()) {
        var request = URLRequest(url: URL(string: url + "/publish")!)
        request.timeoutInterval = 60
        request.httpBody = message
        request.httpShouldHandleCookies = false
        let queue = OperationQueue()

        let task = URLSession.shared.dataTask(with: request){ data, response, error in
            if error != nil {
                finished(0)
                return
            }
            finished((response as! HTTPURLResponse).statusCode)
        }
    }
}
