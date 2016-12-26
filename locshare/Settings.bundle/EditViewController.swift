//
//  EditViewController.swift
//  locshare
//
//  Created by Kenny Levinsen on 10/27/16.
//  Copyright © 2016 Kenny Levinsen. All rights reserved.
//

import UIKit

class EditViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(editUser(_:)))
        self.navigationItem.rightBarButtonItem = doneButton
        let backButton = UIBarButtonItem(title:"", style:.plain, target:nil, action:nil)
        self.navigationItem.backBarButtonItem = backButton

        // Do any additional setup after loading the view.
    }

    func editUser(_ sender: Any) {
        
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
