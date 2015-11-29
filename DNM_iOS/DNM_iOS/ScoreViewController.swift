//
//  ScoreViewController.swift
//  DNM_iOS
//
//  Created by James Bean on 11/26/15.
//  Copyright © 2015 James Bean. All rights reserved.
//

import UIKit
import DNMModel

class ScoreViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - UI
    
    @IBOutlet weak var previousPageButton: UIButton!
    @IBOutlet weak var nextPageButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var viewSelectorTableView: UITableView!
    
    // integrate contexts of Environment into this
    var environment: Environment!
    
    var viewIDs: [String] = []
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make good decisions re: UX and order of loading pages / views asynchrously
        
        setupTableView()
        // create views
    }
    
    func setupTableView() {
        viewSelectorTableView.delegate = self
        viewSelectorTableView.dataSource = self
        viewSelectorTableView.tableFooterView = UIView(frame: CGRectZero)
    }
    
    func manageColorMode() {
        view.backgroundColor = DNMColorManager.backgroundColor
    }
    
    func showScoreWithScoreModel(scoreModel: DNMScoreModel) {
        manageColorMode()
        createEnviromentWithScoreModel(scoreModel)
    }
    
    func createEnviromentWithScoreModel(scoreModel: DNMScoreModel) {
        environment = Environment(scoreModel: scoreModel)
        environment.build()
        view.insertSubview(environment, atIndex: 0)
        
        // createViewIDs
        viewIDs = scoreModel.instrumentIDsAndInstrumentTypesByPerformerID.map { $0.0 } + ["omni"]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func goToNextPage() {
        print("go to next page")
    }
    
    func goToPreviousPage() {
        print("go to prev page")
    }
    
    
    @IBAction func didPressPreviousButton(sender: UIButton) {
        print("did press prev button")
        goToPreviousPage()
    }
    
    @IBAction func didPressNextButton(sender: UIButton) {
        print("did press next button")
        goToNextPage()
    }
    
    // MARK: - View Selector UITableViewDelegate
    
    
    // MARK: - View Selector UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewIDs.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        /*
        let cell = tableView.dequeueReusableCellWithIdentifier("cell",
            forIndexPath: indexPath
        ) as! MasterTableViewCell
        */
        cell.textLabel?.text = viewIDs[indexPath.row]
        return cell
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
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
