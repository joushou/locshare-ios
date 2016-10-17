//
//  MasterViewController.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/17/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import UIKit
import CoreLocation

class UserListItem {
    var user : User
    var location : CLLocation?
    private var distance : Double?
    private var locationStr : String?

    init(user : User) {
        self.user = user
        self.location = nil
        self.distance = nil
        self.locationStr = nil
    }

    func updateLocation(from: CLLocation?) -> Bool {
        let newLocation = user.getLastLocation()
        let needUpdate = newLocation != nil && (
            location == nil ||
                locationStr == nil ||
                location!.horizontalAccuracy <= newLocation!.horizontalAccuracy * 1.5 ||
                newLocation!.distance(from: location!) < 10)

        location = newLocation
        if from != nil && location != nil {
            distance = newLocation!.distance(from: from!)
        } else {
            distance = nil
        }

        return needUpdate
    }

    var locationString : String {
        get {
            if location == nil {
                return "Location not known"
            }

            if locationStr != nil && locationStr?.characters.count != 0 {
                return locationStr!
            }

            let latitudeSuffix = location!.coordinate.latitude >= 0 ? "N" : "S"
            let longitudeSuffix = location!.coordinate.longitude >= 0 ? "E" : "W"

            return String(format: "%.5f°\(latitudeSuffix) %.5f°\(longitudeSuffix)",
                abs(location!.coordinate.latitude),
                abs(location!.coordinate.longitude))
        }
        set(locstr) {
            locationStr = locstr
        }

    }

    var distanceString : String {
        if distance == nil {
            return "N/A"
        }

        if distance! > 999999 {
            return String(format: "%.1f Mm", distance!/1000000)
        } else if distance! > 999 {
            return String(format: "%.1f km", distance!/1000)
        } else if distance! > 0.999 {
            return String(format: "%.1f m", distance!)
        } else {
            return String(format: "%.1f mm", distance!*1000)
        }
    }

    var timeString : String {
        if location == nil {
            return ""
        }

        if location!.timestamp.timeIntervalSinceNow < 60000 {
            return "Now"
        }

        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.year,.month,.weekOfYear,.day,.hour,.minute,.second]
        dateComponentsFormatter.maximumUnitCount = 1
        dateComponentsFormatter.unitsStyle = .full
        dateComponentsFormatter.maximumUnitCount = 1
        if let str = dateComponentsFormatter.string(from: location!.timestamp, to: Date()) {
            return str + " ago"
        }
        return ""
    }
}

class MasterViewController: UITableViewController {
    var detailViewController: DetailViewController? = nil
    var objects = [UserListItem]()
    var locationSubscriber : LocationSubscriber?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem

        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }

        self.refreshControl?.addTarget(self, action: #selector(handleRefresh(_:)), for: UIControlEvents.valueChanged)


        let user = User(uuid: "0m8AOIYe0Bv4Ops8/h6qIcWlb9M55CTOLwPp0JhZVzk=",
                        localPrivKey: Data(base64Encoded: "mMW3DY+x/QnMPAINeiXf+53RIgBPupp9r63IjlJoun4=")!,
                        localPubKey: Data(base64Encoded: "0m8AOIYe0Bv4Ops8/h6qIcWlb9M55CTOLwPp0JhZVzk=")!,
                        remotePubKey: Data(base64Encoded: "0m8AOIYe0Bv4Ops8/h6qIcWlb9M55CTOLwPp0JhZVzk=")!,
                        name: "Test")

        Users.addUser(user: user)
    }

    override func viewWillDisappear(_ animated: Bool) {
        locationSubscriber?.close()
        locationSubscriber = nil
        super.viewWillDisappear(animated)
    }

    func handleRefresh(_ refreshControl: UIRefreshControl) {
        refresh()
        refreshControl.endRefreshing()
    }

    func update(_ uuid: String) {
        refresh()
    }

    func refresh() {
        let geocoder = CLGeocoder()
        for item in objects {
            if !item.updateLocation(from: lastLocation) {
                continue
            }
            if item.location == nil {
                continue
            }

            geocoder.reverseGeocodeLocation(item.location!, completionHandler: { (places, error) in
                if let places = places {
                    if places.count > 0 {
                        item.locationString = places[0].singleLine
                        self.tableView.reloadData()
                    }
                }
            })

        }
        self.tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed

        objects = Users.map { UserListItem(user: $1) }
        refresh()

        let defaults = UserDefaults.standard
        let ip_address = defaults.string(forKey: "server_preference")!
        let port = defaults.integer(forKey: "port_preference")

        locationSubscriber = LocationSubscriber(ip_address: ip_address, port: port, notifier: update)

        _ = Users.map { (uuid, user) in self.locationSubscriber?.subscribe(uuid: uuid) }
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let object = objects[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = object
                controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserTableViewCell", for: indexPath) as! UserTableViewCell

        let object = objects[indexPath.row]
        cell.nameLabel.text = object.user.name
        cell.locationLabel.text = object.locationString
        cell.distanceLabel.text = object.distanceString
        cell.timeLabel.text = object.timeString

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            objects.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
}
