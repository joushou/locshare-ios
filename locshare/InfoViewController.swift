//
//  InfoViewController.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/24/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController {
    @IBOutlet weak var coordinateField: UILabel!
    @IBOutlet weak var addressField: UILabel!
    @IBOutlet weak var movementField: UILabel!

    var user : User?

    override func viewDidLoad() {
        super.viewDidLoad()

        let backButton = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
        self.navigationItem.backBarButtonItem = backButton
        if let user = user {
            if let loc = user.getLastLocation() {
                coordinateField.text = loc.coordinate.coordinateString
                addressField.text = "Unavailable"
                movementField.text = "Unavailable"
            }
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
