//
//  TeamDetailsTableViewController.swift
//  scout-viewer-2016-iOS
//
//  Created by Citrus Circuits on 2/18/15.
//  Copyright (c) 2016 Citrus Circuits. All rights reserved.
//

import UIKit
import MWPhotoBrowser
import SDWebImage
import Haneke


class TeamDetailsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, MWPhotoBrowserDelegate, UIDocumentInteractionControllerDelegate, UINavigationControllerDelegate {
    
    var firebaseFetcher = AppDelegate.getAppDelegate().firebaseFetcher
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var teamNumberLabel: UILabel!
    @IBOutlet weak var teamNameLabel: UILabel!
    @IBOutlet weak var teamSelectedImageView: UIImageView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var seed: UILabel!
    @IBOutlet weak var predictedSeed: UILabel!
    
    var team: Team? = nil {
        didSet {
            num = self.team?.number?.intValue
            updateTitleAndTopInfo()
            reload()
        }
    }
    
    var num: Int? = nil
    var showMinimalistTeamDetails = true
    var shareController: UIDocumentInteractionController!
    var photoBrowser = MWPhotoBrowser()
    var photos: [MWPhoto] = []
    
    func reload() {
        if team != nil {
            if team?.number != nil {
                tableView?.reloadData()
                self.updateTitleAndTopInfo()
                tableViewHeightConstraint?.constant = (tableView.contentSize.height)
                
                self.reloadImage()
            }
        }
        
    }
    
    func reloadImage() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            if let team = self.team,
                let imageView = self.teamSelectedImageView {
                    if team.selectedImageUrl != nil {
                        self.firebaseFetcher?.getImageForTeam(self.team?.number as! Int, fetchedCallback: { (image) -> () in
                            DispatchQueue.main.async(execute: { () -> Void in
                                imageView.image = image
                            })
                            }, couldNotFetch: {
                                DispatchQueue.main.async(execute: { () -> Void in
                                    
                                    imageView.hnk_setImageFromURL(URL(string: team.selectedImageUrl!)!)
                                })
                        })
                    }
                    let noRobotPhoto = UIImage(named: "SorryNoRobotPhoto")
                    if self.teamSelectedImageView.image != noRobotPhoto {
                        self.photos.append(MWPhoto(image: self.teamSelectedImageView.image))
                    }
                    if let urls = self.team?.otherImageUrls {
                        for (_, url) in urls {
                            self.photos.append(MWPhoto(url: URL(string: url as! String)))
                        }
                    }
                    if self.teamSelectedImageView.image == noRobotPhoto && self.photos.count > 0 {
                        if self.photos.count > 0 && self.photos[0].underlyingImage != noRobotPhoto && (self.photos[0].underlyingImage ?? UIImage()).size.height > 0 {
                            DispatchQueue.main.async(execute: { () -> Void in
                                
                                self.teamSelectedImageView.image = self.photos[0].underlyingImage
                            })
                        }
                    }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.reload()
        NotificationCenter.default.addObserver(self, selector: #selector(TeamDetailsTableViewController.reloadTableView(_:)), name:NSNotification.Name(rawValue: "updateLeftTable"), object:nil)
       
        tableView.register(UINib(nibName: "MultiCellTableViewCell", bundle: nil), forCellReuseIdentifier: "MultiCellTableViewCell")
        tableView.delegate = self
        self.navigationController?.delegate = self
        self.photoBrowser.delegate = self
        photos = []
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(TeamDetailsTableViewController.rankingDetailsSegue(_:)))
        self.view.addGestureRecognizer(longPress)
        let longPressForMoreDetail = UILongPressGestureRecognizer(target: self, action: #selector(TeamDetailsTableViewController.didLongPressForMoreDetail(_:)))
        self.teamNumberLabel.addGestureRecognizer(longPressForMoreDetail)
        let tap = UITapGestureRecognizer(target: self, action: #selector(TeamDetailsTableViewController.didTapImage(_:)))
        self.teamSelectedImageView.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        reloadImage()
    }
    
    
    
    func didLongPressForMoreDetail(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.recognized {
            self.showMinimalistTeamDetails = !self.showMinimalistTeamDetails
            self.reload()
            self.teamNumberLabel.textColor = UIColor.black
        } else if recognizer.state == UIGestureRecognizerState.began {
            self.teamNumberLabel.textColor = UIColor.green
        } 
    }
    
    func didTapImage(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.recognized {
            let nav = UINavigationController(rootViewController: self.photoBrowser)
            nav.delegate = self
            self.present(nav, animated: true, completion: nil)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.delegate = nil
        super.viewWillDisappear(animated)
    }
    
    @IBAction func exportTeamPDFs(_ sender: UIBarButtonItem) {
        //sender.isEnabled = false
        //let pdfPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0].appending("team_cards.pdf")
        
        //let pdfPath = dir.appendingPathComponent("team_cards.pdf")
        //_ = URL(fileURLWithPath: pdfPath)
        //print("Rendering PDF...")
        
        /*PDFRenderer.renderPDFToPath(pdfPath) {(progress: Float, done: Bool) -> () in
        self.navigationController?.setSGProgressPercentage(progress * 100)
        
        if(done) {
        print("Done rendering PDF")
        
        self.shareController = self.setupControllerWithURL(pdfURL, usingDelegate: self)
        self.shareController.presentPreviewAnimated(true)
        sender.enabled = true
        }
        }*/
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if team == nil {
            return 44
        }
        
        let dataKey: String = Utils.teamDetailsKeys.keySets(self.showMinimalistTeamDetails)[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        if Utils.teamDetailsKeys.longTextCells.contains(dataKey) {
            let dataPoint: AnyObject = team!.value(forKeyPath: dataKey) as AnyObject? ?? "" as AnyObject
            
            let titleText = Utils.humanReadableNames[dataKey]
            let notesText = "\(roundValue(dataPoint, toDecimalPlaces: 2))"
            
            let attrs = [NSFontAttributeName : UIFont.systemFont(ofSize: 16)]
            return (titleText! as NSString).size(attributes: attrs).height + (notesText as NSString).size(attributes: attrs).height + 44
        } else {
            return 44
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return team == nil ? nil : Utils.teamDetailsKeys.keySetNames(self.showMinimalistTeamDetails)[section]
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return team == nil ? 1 : Utils.teamDetailsKeys.keySetNames(self.showMinimalistTeamDetails).count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return team == nil ? 1 : Utils.teamDetailsKeys.keySets(self.showMinimalistTeamDetails)[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        if team != nil {
            if team!.number == nil {
                cell = tableView.dequeueReusableCell(withIdentifier: "TeamInMatchDetailStringCell", for: indexPath)
                cell.textLabel?.text = "No team yet..."
                cell.accessoryType = UITableViewCellAccessoryType.none
                return cell
            }
            
            let dataKey: String = Utils.teamDetailsKeys.keySets(self.showMinimalistTeamDetails)[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
            
            if !Utils.teamDetailsKeys.defaultKeys.contains(dataKey) { //Default keys are currently just 'matches'
                var dataPoint = AnyObject?.init(nilLiteral: ())
                var secondDataPoint = AnyObject?.init(nilLiteral: ())

                
                dataPoint = team!.value(forKeyPath: dataKey) as AnyObject?? ?? "" as AnyObject?
                
                if Utils.teamDetailsKeys.obstacleKeys.contains(dataKey) {
                    secondDataPoint = team!.value(forKeyPath: dataKey.replacingOccurrences(of: "Auto", with: "Tele")) as AnyObject?
                    
                    if let sf = secondDataPoint as? Float? {
                        secondDataPoint = "\(roundValue(sf as AnyObject?, toDecimalPlaces: 1))" as AnyObject?
                    }
                }
                
                if secondDataPoint as? String == "" {
                    secondDataPoint = nil
                }
                
                if Utils.teamDetailsKeys.longTextCells.contains(dataKey) {
                    let notesCell: ResizableNotesTableViewCell = tableView.dequeueReusableCell(withIdentifier: "TeamInMatchDetailStringCell", for: indexPath) as! ResizableNotesTableViewCell
                    
                    notesCell.titleLabel?.text = Utils.humanReadableNames[dataKey]
                    
                    if "\(dataPoint)".isEmpty {
                        notesCell.notesLabel?.text = "None"
                    } else {
                        notesCell.notesLabel?.text = "\(dataPoint!)"
                    }
                    notesCell.selectionStyle = UITableViewCellSelectionStyle.none
                    cell = notesCell
                } else if Utils.teamDetailsKeys.unrankedCells.contains(dataKey) || dataKey.contains("pit") {
                    let unrankedCell: UnrankedTableViewCell = tableView.dequeueReusableCell(withIdentifier: "UnrankedCell", for: indexPath) as! UnrankedTableViewCell
                    
                    unrankedCell.titleLabel.text = Utils.humanReadableNames[dataKey]
                    
                    if "\(dataPoint)".isEmpty || (dataPoint as? Float != nil && dataPoint as! Float == 0.0) {
                        unrankedCell.detailLabel.text = ""
                    } else if dataKey == "pitOrganization" { //In the pit scout, the selector is indexed 0 to 4, this translates it back in to what those numbers mean.
                        unrankedCell.detailLabel!.text! = pitOrgForNumberString(unrankedCell.detailLabel!.text!)
                    } else if dataKey == "pitProgrammingLanguage" {
                        unrankedCell.detailLabel!.text! = pitProgrammingLanguageForNumberString(unrankedCell.detailLabel!.text!)
                    } else if Utils.teamDetailsKeys.addCommasBetweenCapitals.contains(dataKey) {
                        unrankedCell.detailLabel.text = "\(insertCommasAndSpacesBetweenCapitalsInString(roundValue(dataPoint!, toDecimalPlaces: 2)))"
                    } else if Utils.teamDetailsKeys.boolValues.contains(dataKey) {
                        unrankedCell.detailLabel.text = "\(boolToBoolString(dataPoint as! Bool))"
                    } else {
                        unrankedCell.detailLabel.text = "\(roundValue(dataPoint!, toDecimalPlaces: 2))"
                    }
                    
                    unrankedCell.selectionStyle = UITableViewCellSelectionStyle.none
                    cell = unrankedCell
                } else {
                    let multiCell: MultiCellTableViewCell = tableView.dequeueReusableCell(withIdentifier: "MultiCellTableViewCell", for: indexPath) as! MultiCellTableViewCell
                    
                    multiCell.teamLabel!.text = Utils.humanReadableNames[dataKey]
                    
                    if secondDataPoint != nil { //This means that it is a defense crossing
                        if secondDataPoint as? String != "" && dataPoint as? String != "" {
                            if let ff = dataPoint as? Float {
                                dataPoint = roundValue(ff as AnyObject?, toDecimalPlaces: 1) as AnyObject?? ?? "" as AnyObject?
                            }
                            multiCell.scoreLabel?.text = "A: \(dataPoint!) T: \(secondDataPoint!)"
                        }
                    } else { //Its not a defense crossing
                        
                        if Utils.teamDetailsKeys.percentageValues.contains(dataKey) {
                            multiCell.scoreLabel!.text = "\(percentageValueOf(dataPoint!))"
                        } else {
                            if dataPoint as? String != "" {
                                if Utils.teamDetailsKeys.plus1Keys.contains(dataKey) { //Something ranked with a 1-5 selector, but the indecles that would come back from such a selector are 0-4
                                    multiCell.scoreLabel?.text = "\(roundValue(NSNumber(value: dataPoint! as! Float + 1.00), toDecimalPlaces: 2))"
                                } else if Utils.teamDetailsKeys.yesNoKeys.contains(dataKey) {
                                    if dataPoint! as! Bool == true {
                                        multiCell.scoreLabel?.text = "Yes"
                                    } else {
                                        multiCell.scoreLabel?.text = "No"
                                    }
                                } else { // it is neither a yes/no or a +1 key.
                                    multiCell.scoreLabel!.text = "\(roundValue(dataPoint!, toDecimalPlaces: 2))"
                                }
                            } else {
                                multiCell.scoreLabel?.text = ""
                            }
                        }
                        if multiCell.teamLabel?.text?.range(of: "Accuracy") != nil || multiCell.teamLabel?.text?.range(of: "Consistency") != nil { //Anything with the words "Accuracy" or "Consistency" should be a percentage
                            multiCell.scoreLabel!.text = percentageValueOf(dataPoint!)
                        }
                        
                        /*//Low Shots Attempted Tele
                        if multiCell.teamLabel?.text?.rangeOfString("Accuracy") != nil && multiCell.teamLabel?.text?.rangeOfString("Low") != nil {
                        var counter = 0
                        for TIM in (data?.TeamInMatchDatas)! {
                        if TIM.calculatedData?.lowShotsAttemptedTele != nil {
                        counter += (TIM.calculatedData!.lowShotsAttemptedTele?.integerValue)!
                        }
                        }
                        if counter == 0 {
                        multiCell.scoreLabel!.text = "0 Attempted"
                        }
                        }
                        if multiCell.teamLabel?.text?.rangeOfString("Accuracy") != nil && multiCell.teamLabel?.text?.rangeOfString("High") != nil {
                        var counter = 0
                        for TIM in (data?.TeamInMatchDatas)! {
                        if TIM.calculatedData?.highShotsAttemptedTele != nil {
                        counter += (TIM.calculatedData!.highShotsAttemptedTele?.integerValue)!
                        }
                        }
                        if(counter == 0) {
                        multiCell.scoreLabel!.text = "0 Attempted"
                        }
                        }*/
                        
                        
                        
                        //                multiCell.selectionStyle = UITableViewCellSelectionStyle.None
                        
                    }
                    cell = multiCell
                    multiCell.rankLabel!.text = "\((firebaseFetcher?.rankOfTeam(team!, withCharacteristic: dataKey))! as Int)"
                }
            } else {
                let unrankedCell: UnrankedTableViewCell = tableView.dequeueReusableCell(withIdentifier: "UnrankedCell", for: indexPath) as! UnrankedTableViewCell
                
                unrankedCell.titleLabel.text = Utils.humanReadableNames[dataKey]
                unrankedCell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
                
                if dataKey == "matchDatas" {
                    let matchesUntilNextMatch : String = firebaseFetcher?.matchesUntilTeamNextMatch(team?.number as! Int) ?? "NA"
                    
                    unrankedCell.titleLabel.text = (unrankedCell.titleLabel.text)! + " - (\(matchesUntilNextMatch))  Remaining: \(Utils.sp(thing: firebaseFetcher?.remainingMatchesForTeam((team?.number?.intValue)!)))"
                }
                cell = unrankedCell
            }
            
            
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "TeamInMatchDetailStringCell", for: indexPath)
            cell.textLabel?.text = "No team yet..."
            cell.accessoryType = UITableViewCellAccessoryType.none
        }
        return cell
    }
    /**
     Translates numbers into what it actually means.
     
     - parameter numString: e.g. "0" -> "Terrible"
     
     - returns: A string with the human readable pit org
     */
    func pitOrgForNumberString(_ numString: String) -> String {
        var translated = ""
        switch numString {
        case "0": translated = "Terrible"
        case "1": translated = "Bad"
        case "2": translated = "OK"
        case "3": translated = "Good"
        case "4": translated = "Great"
        default: break
        }
        return translated

    }
    /**
     Translates numbers into what it actually means.
     
     - parameter numString: e.g. "0" -> "C++"
     
     - returns: A string with the human readable prog lang name.
     */
    func pitProgrammingLanguageForNumberString(_ numString: String) -> String {
        var translated = ""
        switch numString {
        case "0": translated = "C++"
        case "1": translated = "Java"
        case "2": translated = "Labview"
        case "3": translated = "Other"
        default: break
        }
        return translated

    }
    
    func updateTitleAndTopInfo() {
        if self.teamNameLabel != nil {
            if self.teamNameLabel.text == "" || self.teamNameLabel.text == "Unknown name..." {
                let numText: String
                let nameText: String
                switch (team?.number, team?.name) {
                case (.some(let num), .some(let name)):
                    title = "\(num)"
                    numText = "\(num)"
                    nameText = "\(name)"
                case (.some(let num), .none):
                    title = "\(num)"
                    numText = "\(num)"
                    nameText = "Unknown name..."
                case (.none, .some(let name)):
                    title = "Unkown Number"
                    numText = "????"
                    nameText = "\(name)"
                default:
                    title = "Unknown Number"
                    numText = "????"
                    nameText = "Unknown name..."
                }
                
                teamNameLabel?.text = nameText
                teamNumberLabel?.text = numText
            }
            
            
            var seedText = "?"
            var predSeedText = "?"
            if let seed = team?.calculatedData!.actualSeed , seed.intValue > 0 {
                seedText = "\(seed)"
            }
            
            if let predSeed = team?.calculatedData!.predictedSeed , predSeed.intValue > 0 {
                predSeedText = "\(predSeed)"
            }
            
            
            seed?.text = seedText
            predictedSeed?.text = predSeedText
        }
    }
    
    func numberOfPhotos(in photoBrowser: MWPhotoBrowser!) -> UInt {
        return UInt(photos.count)
    }
    
    func photoBrowser(_ photoBrowser: MWPhotoBrowser!, photoAt index: UInt) -> MWPhotoProtocol! {
        if index < UInt(photos.count) {
            return photos[Int(index)]
        }
        return nil;
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.teamSelectedImageView.isUserInteractionEnabled = true;
        //        self.n
        //navigationController?.setSGProgressPercentage(50.0)
        if segue.identifier == "sortedRankSegue" {
            if let dest = segue.destination as? SortedRankTableViewController {
                dest.keyPath = sender as! String
            }
        }
        if segue.identifier == "defenseCrossedSegue" {
            let indexPath = sender as? IndexPath
            let cell = tableView.cellForRow(at: indexPath!) as? MultiCellTableViewCell
            let dest = segue.destination as? DefenseTableViewController
            if let teamNumbah = team?.number {
                dest!.teamNumber = teamNumbah.intValue
                dest!.relevantDefense = cell!.teamLabel!.text!
                dest!.defenseKey = Utils.getKeyForHumanReadableName(dest!.relevantDefense)!.characters.split{$0 == "."}.map(String.init)[2]
            }
        }
        else if segue.identifier == "Photos" {
            let browser = segue.destination as! MWPhotoBrowser;
            
            browser.delegate = self;
            
            browser.displayActionButton = true; // Show action button to allow sharing, copying, etc (defaults to YES)
            browser.displayNavArrows = false; // Whether to display left and right nav arrows on toolbar (defaults to NO)
            browser.displaySelectionButtons = false; // Whether selection buttons are shown on each image (defaults to NO)
            browser.zoomPhotosToFill = true; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
            browser.alwaysShowControls = false; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
            browser.enableGrid = false; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
            
            SDImageCache.shared().maxCacheSize = UInt(20 * 1024 * 1024);
        } else if segue.identifier == "Matches" {
            let matchesForTeamController = segue.destination as! SpecificTeamScheduleTableViewController
            
            if let teamNum = team?.number {
                matchesForTeamController.teamNumber = teamNum.intValue
            }
        } else if segue.identifier == "CTIMDGraph" {
            let graphViewController = segue.destination as! GraphViewController
            
            
            if let teamNum = team?.number {
                let indexPath = sender as! IndexPath
                if let cell = tableView.cellForRow(at: indexPath) as? MultiCellTableViewCell {
                    graphViewController.graphTitle = "\(cell.teamLabel!.text!)"
                    graphViewController.displayTitle = "\(graphViewController.graphTitle): "
                    var key = Utils.getKeyForHumanReadableName(graphViewController.graphTitle)
                    
                    
                    key = key?.replacingOccurrences(of: "calculatedData.", with: "")
                    switch key! { // Should really just be a dictionary
                    case "reachPercentage": key = "didReachAuto"
                    case "scalePercentage": key = "didScaleTele"
                    case "incapacitatedPercentage": key = "didGetIncapacitated"
                    case "disabledPercentage": key = "didGetDisabled"
                    case "challengePercentage": key = "didChallengeTele"
                    case "avgShotsBlocked": key = "numShotsBlockedTele"
                    case "avgLowShotsTele": key = "numLowShotsMadeTele"
                    case "avgHighShotsTele": key = "numHighShotsMadeTele"
                    case "avgBallsKnockedOffMidlineAuto": key = "numBallsKnockedOffMidlineAuto"
                    case "avgMidlineBallsIntakedAuto": key = "calculatedData.numBallsIntakedOffMidlineAuto"
                    case "avgSpeed": key = "rankSpeed"
                    case "avgAgility": key = "rankAgility"
                    case "avgTorque": key = "rankTorque"
                    case "avgBallControl": key = "rankBallControl"
                    case "avgLowShotsAttemptedTele": key = "calculatedData.lowShotsAttemptedTele"
                    case "avgHighShotsAttemptedAuto": key = "calculatedData.highShotsAttemptedAuto"
                    case "avgHighShotsAttemptedTele": key = "calculatedData.highShotsAttemptedTele"
                    case "RScoreDrivingAbility": key = "calculatedData.drivingAbility"
                    case "RScoreBallControl": key = "rankBallControl"
                    case "RScoreAgility": key = "rankAgility"
                    case "RScoreDefense": key = "rankDefense"
                    case "RScoreSpeed": key = "rankSpeed"
                    case "RScoreTorque": key = "rankTorque"
                    case "avgGroundIntakes": key = "numGroundIntakesTele"
                    case "avgDefense": key = "rankDefense"
                    case "actualNumRPs": key = "calculatedData.numRPs"
                    case "siegeConsistency": key = "calculatedData.siegeConsistency"
                    case "teleopShotAbility": key = "calculatedData.teleopShotAbility"
                    case "lowShotAccuracyTele": key = "calculatedData.lowShotAccuracyTele"
                    case "highShotAccuracyTele": key = "calculatedData.highShotAccuracyTele"
                    case "lowShotAccuracyAuto": key = "calculatedData.lowShotAccuracyAuto"
                    case "highShotAccuracyAuto": key = "calculatedData.highShotAccuracyAuto"
                    case "numAutoPoints": key = "calculatedData.numAutoPoints"
                    case "disfunctionalPercentage": key = "calculatedData.wasDisfunctional"
                    case "avgNumTimesCrossedDefensesAuto": key = "calculatedData.totalNumTimesCrossedDefensesAuto"
                    case "avgHighShotsAuto": key = "numHighShotsMadeAuto"
                    case "avgLowShotsAuto": key = "numLowShotsMadeAuto"
                    default: break
                    }
                    
                    
                    var values: [Float]
                    let altMapping : [CGFloat: String]?
                    if key == "calculatedData.predictedNumRPs" {
                        
                        (values, altMapping) = (firebaseFetcher!.getMatchDataValuesForTeamForPath(key!, forTeam: team!))
                    } else {
                        (values, altMapping) = (firebaseFetcher?.getMatchValuesForTeamForPath(key!, forTeam: team!))!
                    }
                    if key?.range(of: "Accuracy") != nil {
                        graphViewController.isPercentageGraph = true
                    }
                    /*if values.reduce(0, combine: +) == 0 || values.count == 0 {
                    graphViewController.graphTitle = "Data Is All 0s"
                    graphViewController.values = [CGFloat]()
                    graphViewController.subValuesLeft = [CGFloat]()
                    if altMapping != nil {
                    graphViewController.zeroAndOneReplacementValues = altMapping!
                    }
                    } else {
                    //print(values)*/
                    var nilValueIndecies = [Int]()
                    for i in 0..<values.count {
                        if values[i] == -1111.1 {
                            nilValueIndecies.append(i)
                        }
                    }
                    for i in nilValueIndecies.reversed() {
                        values.remove(at: i)
                    }
                    
                    graphViewController.values = (values as NSArray).map { CGFloat($0 as! Float) }
                    graphViewController.subDisplayLeftTitle = "Match: "
                    graphViewController.subValuesLeft = nsNumArrayToIntArray(firebaseFetcher!.matchNumbersForTeamNumber(team?.number as! Int)) as [AnyObject]
                    for i in nilValueIndecies.reversed() {
                        graphViewController.subValuesLeft.remove(at: i)
                    }
                    
                    if altMapping != nil {
                        graphViewController.zeroAndOneReplacementValues = altMapping!
                    }
                    //print("Here are the subValues \(graphViewController.values.count)::\(graphViewController.subValuesLeft.count)")
                    //print(graphViewController.subValuesLeft)
                    //}
                    /*if let d = data {
                    graphViewController.subValuesRight =
                    nsNumArrayToIntArray(firebaseFetcher.ranksOfTeamInMatchDatasWithCharacteristic(keySets[indexPath.section][indexPath.row], forTeam:firebaseFetcher.fetchTeam(d.number!.integerValue)))
                    
                    let i = ((graphViewController.subValuesLeft as NSArray).indexOfObject("\(teamNum)"))
                    graphViewController.highlightIndex = i
                    
                    }*/
                    graphViewController.subDisplayRightTitle = "Team: "
                    graphViewController.subValuesRight = [teamNum,teamNum,teamNum,teamNum,teamNum]
                    
                    
                }
            }
        }
        else if segue.identifier == "TGraph" {
            let graphViewController = segue.destination as! GraphViewController
            
            if let teamNum = team?.number {
                let indexPath = sender as! IndexPath
                let cell = tableView.cellForRow(at: indexPath) as! MultiCellTableViewCell
                graphViewController.graphTitle = "\(cell.teamLabel!.text!)"
                graphViewController.displayTitle = "\(graphViewController.graphTitle): "
                if let values = firebaseFetcher?.valuesInCompetitionOfPathForTeams(Utils.teamDetailsKeys.keySets(self.showMinimalistTeamDetails)[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]) as? [CGFloat] {
                    graphViewController.values = values
                    graphViewController.subValuesLeft = firebaseFetcher!.valuesInCompetitionOfPathForTeams("number") as [AnyObject]
                    graphViewController.subDisplayLeftTitle = "Team "
                    graphViewController.subValuesRight = nsNumArrayToIntArray(firebaseFetcher!.ranksOfTeamsWithCharacteristic(Utils.teamDetailsKeys.keySets(self.showMinimalistTeamDetails)[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row] as NSString) as [NSNumber] ) as [AnyObject]
                    graphViewController.subDisplayRightTitle = "Rank: "
                    if let i = ((graphViewController.subValuesLeft as! [Int]).index(of: teamNum.intValue)) {
                        graphViewController.highlightIndex = i
                    }
                }
                //                graphViewController.heights =]
                //                graphViewController.teamNumber = Int32(teamNum)
                //                graphViewController.graphInfo = nil;
            }
        } else if segue.identifier == "NotesSegue" {
            let notesTableViewController = segue.destination as! NotesTableViewController
            if let teamNum = team?.number  {
                if let p = team?.pitNotes {
                    notesTableViewController.data.append(["Pit Notes: ": p])
                } else {
                    notesTableViewController.data.append(["Pit Notes: ": "None"])
                }
                for TIMD in (firebaseFetcher?.getTIMDataForTeam(team!))! {
                    if let note = TIMD.superNotes {
                        notesTableViewController.data.append(["Match \(TIMD.matchNumber!.intValue)":"\(note)"])
                    } else {
                        notesTableViewController.data.append(["Match \(TIMD.matchNumber!.intValue)":"None"])
                    }
                }
                notesTableViewController.title = "\(teamNum) Notes"
            }
        }
    }
    
    func boolToBoolString(_ b: Bool) -> String {
        let strings = [false : "No", true : "Yes"]
        return strings[b]!
    }
    
    func setupControllerWithURL(_ fileURL: URL, usingDelegate: UIDocumentInteractionControllerDelegate) -> UIDocumentInteractionController {
        let interactionController = UIDocumentInteractionController(url: fileURL)
        interactionController.delegate = usingDelegate
        
        return interactionController
    }
    
    //    - (UIDocumentInteractionController *) setupControllerWithURL: (NSURL *)fileURL usingDelegate: (id <UIDocumentInteractionControllerDelegate>) interactionDelegate {
    //    
    //    UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL: fileURL];
    //    interactionController.delegate = interactionDelegate;
    //    
    //    return interactionController;
    //    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? UnrankedTableViewCell {
            if cell.titleLabel.text?.range(of: "Matches") != nil {
                performSegue(withIdentifier: "Matches", sender: nil)
            }
        } else if let cell = tableView.cellForRow(at: indexPath) as? MultiCellTableViewCell {
            let cs = cell.teamLabel!.text
            if ((cs ?? "").contains("Times Crossed"))  {
                performSegue(withIdentifier: "defenseCrossedSegue", sender:indexPath)
            } else if((Utils.getKeyForHumanReadableName(cs!)) != nil) {
                if !Utils.teamDetailsKeys.notGraphingValues.contains(cs!) && !cs!.contains("σ") { performSegue(withIdentifier: "CTIMDGraph", sender: indexPath) }
            } else {
                performSegue(withIdentifier: "TGraph", sender: indexPath)
            }
            
        } else if let cell = tableView.cellForRow(at: indexPath) as? ResizableNotesTableViewCell {
            //Currently the only one is pit notes. We want it to segue to super notes per match
            if cell.textLabel?.text == "Pit Notes" {
                performSegue(withIdentifier: "NotesSegue", sender: indexPath)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    func reloadTableView(_ note: Notification) {
        if note.name.rawValue == "updateLeftTable" {
            if let t = note.object as? Team {
                if t.number == team?.number {
                    self.team = t
                    self.reload()
                }
            }
            
        }
    }
    
    func rankingDetailsSegue(_ gesture: UIGestureRecognizer) {
        
        if(gesture.state == UIGestureRecognizerState.began) {
            let p = gesture.location(in: self.tableView)
            let indexPath = self.tableView.indexPathForRow(at: p)
            if let index = indexPath {
                if let cell = self.tableView.cellForRow(at: index) as? MultiCellTableViewCell {
                    if cell.teamLabel!.text!.contains("Crossed") == false {
                        performSegue(withIdentifier: "sortedRankSegue", sender: cell.teamLabel!.text)
                    }
                }
            }
            
            
        }
    }
}


