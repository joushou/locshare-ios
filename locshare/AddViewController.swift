//
//  AddViewController.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/22/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import UIKit

class AddViewController: UIViewController {

    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var remotePubKeyField: UITextField!
    @IBOutlet weak var localPubKeyField: UITextField!
    @IBOutlet weak var localPrivKeyField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(addUser(_:)))
        self.navigationItem.rightBarButtonItem = doneButton
        let backButton = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
        self.navigationItem.backBarButtonItem = backButton
        // Do any additional setup after loading the view.


        let (priv, pub) = generate_keypair()
        localPrivKeyField.text = priv.base64EncodedString()
        localPubKeyField.text = pub.base64EncodedString()

    }

    func addUser(_ sender: Any) {
        //        objects.insert(, at: 0)
        //        let indexPath = IndexPath(row: 0, section: 0)
        //        self.tableView.insertRows(at: [indexPath], with: .automatic)

        let name = nameField.text
        let remotePubKey = Data(base64Encoded: remotePubKeyField.text!)
        let localPrivKey = Data(base64Encoded: localPrivKeyField.text!)
        let localPubKey = Data(base64Encoded: localPubKeyField.text!)

        if remotePubKey == nil || localPrivKey == nil || localPubKey == nil {
            return
        }
        if remotePubKey!.count != 32 || localPrivKey!.count != 32 || localPubKey!.count != 32 {
            return
        }

        let user = User(uuid:localPubKeyField.text!,
                        localPrivKey: localPrivKey!,
                        localPubKey: localPubKey!,
                        remotePubKey: remotePubKey!,
                        name: name!)

        Users.addUser(user: user)

        _ = self.navigationController?.popViewController(animated: true)
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
