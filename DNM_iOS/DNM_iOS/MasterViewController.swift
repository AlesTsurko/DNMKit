//
//  MasterViewController.swift
//  DNM_iOS
//
//  Created by James Bean on 11/26/15.
//  Copyright © 2015 James Bean. All rights reserved.
//

import UIKit
import DNMModel
import Parse
import Bolts

class MasterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: UI
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loginStatusLabel: UILabel!
    @IBOutlet weak var signInOrUpOrOnLabel: UILabel!
    @IBOutlet weak var signInOrUpLabel: UILabel!
    @IBOutlet weak var dnmLogoLabel: UILabel!
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    private var scoreObjectSelected: PFObject?
    private var scoreStringSelected: String?
    private var scoreModelSelected: DNMScoreModel?

    // MARK: Score Object Management
    var scoreObjects: [PFObject] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func manageLoginStatus() {
        PFUser.currentUser() == nil ? enterSignInMode() : enterSignedInMode()
    }
    
    override func viewDidAppear(animated: Bool) {
        fetchAllObjectsFromLocalDatastore()
        fetchAllObjects()
        tableView.reloadData()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("prepare for segue: \(segue)")
        if let id = segue.identifier where id == "showScore" {
            print("segue: showScore)")
            let newVC = segue.destinationViewController as! ScoreViewController
            if let scoreModel = scoreModelSelected {
                print("scoreModelSelected: \(scoreStringSelected)")
                newVC.showScoreWithScoreModel(scoreModel)
            }
        }
    }
    
    func makeScoreModelWithString(string: String) -> DNMScoreModel {
        let tokenizer = Tokenizer()
        let tokenContainer = tokenizer.tokenizeString(string)
        let parser = Parser()
        let scoreModel = parser.parseTokenContainer(tokenContainer)
        print("make scoreModel with string: scoreModel: \(scoreModel)")
        return scoreModel
    }

    /*
    func addTestObject() {
        print("add test object")
        
        // need to get url of files (perhaps that are presaved?)
        
        let string = "p 60 d fff a -"
        if let _ = string.dataUsingEncoding(NSUTF8StringEncoding) {
            let score = PFObject(className: "Score")
            score["username"] = testUsername
            score["title"] = "newest piece"
            //score["score"] = scoreFile
            score["text"] = "yes yes yes yes yes"
            print("scoreObj: \(score)")
            
            score.saveEventually { (success, error) -> Void in
                if success {
                    print("success!")
                }
                else {
                    
                }
                if let error = error {
                    print("could not save: \(error)")
                }
            }
        }
    }
    */
    
    func fetchAllObjectsFromLocalDatastore() {
        if let username = PFUser.currentUser()?.username {
            let query = PFQuery(className: "Score")
            query.fromLocalDatastore()
            query.whereKey("username", equalTo: username)
            query.findObjectsInBackgroundWithBlock { (objects, error) -> () in
                if let error = error { print(error) }
                else if let objects = objects {
                    self.scoreObjects = objects
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func fetchAllObjects() {
        if let username = PFUser.currentUser()?.username {
            PFObject.unpinAllObjectsInBackground()
            let query = PFQuery(className: "Score")
            query.whereKey("username", equalTo: username)
            query.findObjectsInBackgroundWithBlock { (objects, error) -> () in
                if error != nil {
                    // error
                }
                else if let objects = objects {
                    self.scoreObjects = objects
                    
                    do {
                        try PFObject.pinAll(objects)
                    }
                    catch {
                        print("couldnt pin")
                    }
                    self.fetchAllObjectsFromLocalDatastore()
                }
            }
        }
    }
    
    //
    func enterSignInMode() {
        loginStatusLabel.hidden = true
        usernameField.hidden = false
        passwordField.hidden = false
    }
    
    // signed in
    func enterSignedInMode() {
        usernameField.hidden = true
        passwordField.hidden = true
        loginStatusLabel.hidden = false
        if let username = PFUser.currentUser()?.username {
            loginStatusLabel.text = "logged in as \(username)"
        }
    }
    
    // need to sign up
    func enterSignUpmMode() {
        print("enter sign up mode")
    }


    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath)
        -> UITableViewCell
    {
        
        print("tableview cell for row at index path: \(indexPath.row)")
        let cell = tableView.dequeueReusableCellWithIdentifier("cell",
            forIndexPath: indexPath
        ) as! MasterTableViewCell
        cell.textLabel?.text = scoreObjects[indexPath.row]["title"] as? String
        
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("did select row")
        if let scoreString = scoreObjects[indexPath.row]["text"] {
            print("score string: \(scoreString)")
            let scoreModel = makeScoreModelWithString(scoreString as! String)
            scoreModelSelected = scoreModel
            print("score model selected: \(scoreModelSelected)")
            performSegueWithIdentifier("showScore", sender: self)
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scoreObjects.count
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
