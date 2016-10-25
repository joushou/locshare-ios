//
//  DetailViewController.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/17/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import UIKit
import MapKit

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!

    var locationSubscriber : LocationSubscriber?
    var annotation : MKPointAnnotation?


    func configureView() {
        // Update the user interface for the detail item.
        if let detail = self.detailItem {
            let defaults = UserDefaults.standard
            let ip_address = defaults.string(forKey: "server_preference")
            let port = defaults.integer(forKey: "port_preference")

            if (ip_address != nil && port != 0) {
                if locationSubscriber == nil {
                    self.locationSubscriber = LocationSubscriber(ip_address: ip_address!, port: port, notifier: self.update)
                    self.locationSubscriber?.subscribe(uuid: detail.user.uuid)
                }
            }

            update(detail.user.uuid)
        }
    }

    func update(_ uuid: String) {
        let user = Users.getUser(uuid: uuid)
        if user == nil {
            return
        }

        if let map = self.mapView {
            if let location = user!.getLastLocation() {
                var old = false
                if annotation != nil {
                    map.removeAnnotation(annotation!)
                    old = true
                }

                annotation = MKPointAnnotation()

                annotation!.coordinate = location.coordinate
                annotation!.title = user!.name
                if old {
                    map.setCenter(location.coordinate, animated: true)
                } else {
                    map.setCamera(MKMapCamera(lookingAtCenter: location.coordinate, fromDistance: 2000, pitch: 0, heading: 0), animated: false)
                }
                map.isZoomEnabled = true
                map.showsUserLocation = true
                map.addAnnotation(annotation!)
                map.showsScale = true
                map.showsCompass = true
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showInfo" {
            if let detail = self.detailItem {
                let controller = segue.destination as! InfoViewController
                controller.user = detail.user
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        locationSubscriber?.close()
        locationSubscriber = nil
        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var detailItem: UserListItem? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }


}


