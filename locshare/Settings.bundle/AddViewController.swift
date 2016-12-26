//
//  AddViewController.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/22/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import UIKit

class AddViewController: UIViewController {
    @IBOutlet weak var usernameField: UITextField!

    @IBOutlet weak var nameField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(addUser(_:)))
        self.navigationItem.rightBarButtonItem = doneButton
        let backButton = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
        self.navigationItem.backBarButtonItem = backButton
        // Do any additional setup after loading the view.
    }

    func addUser(_ sender: Any) {
        //        objects.insert(, at: 0)
        //        let indexPath = IndexPath(row: 0, section: 0)
        //        self.tableView.insertRows(at: [indexPath], with: .automatic)

        let username = usernameField.text

        let user = User(username: username!, name: username!, session: Session(store: InMemorySessionStore(), privateStore: GlobalPrivateStore))

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
