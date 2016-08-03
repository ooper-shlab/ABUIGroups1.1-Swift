//
//  GroupViewController.swift
//  ABUIGroups
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/3/29.
//
//
/*
     File: GroupViewController.h
     File: GroupViewController.m
 Abstract: Prompts a user for access to their address book data, then updates its UI according to their response.
 Adds, displays, and removes group records from Contacts.
  Version: 1.1

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2013 Apple Inc. All Rights Reserved.

*/
import UIKit
//import AddressBook

@objc(GroupViewController)
class GroupViewController: UITableViewController {
    
    
    private var addressBook: MyAddressBook!
    private var sourcesAndGroups: [MySource] = []
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    //MARK: -
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create an address book object
        addressBook = MyAddressBook.createInstance()
        
        //Display all groups available in the Address Book
        self.sourcesAndGroups = []
        
        // Check whether we are authorized to access the user's address book data
        self.checkAddressBookAccess()
    }
    
    
    //MARK: -
    //MARK: Address Book Access
    
    // Check the authorization status of our application for Address Book
    private func checkAddressBookAccess() {
        switch MyAddressBook.authorizationStatus {
            // Update our UI if the user has granted access to their Contacts
        case  .authorized:
            self.accessGrantedForAddressBook()
            // Prompt the user for access to Contacts if there is no definitive answer
        case .notDetermined:
            self.requestAddressBookAccess()
            // Display a message if the user has denied or restricted access to Contacts
        case .denied, .restricted:
            let alertController = UIAlertController(title: "Privacy Warning", message: "Permission was not granted for Contacts.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    
    // Prompt the user for access to their Address Book data
    private func requestAddressBookAccess() {
        
        self.addressBook.requestAccessForContacts {granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.accessGrantedForAddressBook()
                    
                }
            }
        }
    }
    
    
    // This method is called when the user has granted access to their address book data.
    private func accessGrantedForAddressBook() {
        do {
            // Fetch all groups available in address book
            self.sourcesAndGroups = try self.fetchGroupsInAddressBook(self.addressBook)
                
            // Enable the Add button
            self.addButton.isEnabled = true
            // Add the Edit button
            self.navigationItem.leftBarButtonItem = self.editButtonItem
            
            self.tableView.reloadData()
        } catch let error {
            print(error)
        }
    }
    
    
    //MARK: -
    //MARK: Manage groups
    
    // Return the name associated with the given identifier
//    private func nameForSourceWithIdentifier(identifier: Int) -> String? {
//        switch identifier {
//        case kABSourceTypeLocal:
//            return "On My Device"
//        case kABSourceTypeExchange:
//            return "Exchange server"
//        case kABSourceTypeExchangeGAL:
//            return "Exchange Global Address List"
//        case kABSourceTypeMobileMe:
//            return "MobileMe"
//        case kABSourceTypeLDAP:
//            return "LDAP server"
//        case kABSourceTypeCardDAV:
//            return "CardDAV server"
//        case kABSourceTypeCardDAVSearch:
//            return "Searchable CardDAV server"
//        default:
//            break
//        }
//        return nil
//    }
    
    
    // Return the name of a given group
//    private func nameForGroup(group: ABRecord) -> String? {
//        return ABRecordCopyCompositeName(group)?.takeRetainedValue() as String?
//    }
    
    
    // Return the name of a given source
//    private func nameForSource(source: ABRecord) -> String? {
//        // Fetch the source type
//        let sourceType = ABRecordCopyValue(source, kABSourceTypeProperty)!.takeRetainedValue() as! NSNumber
//        
//        // Fetch and return the name associated with the source type
//        return self.nameForSourceWithIdentifier(sourceType.integerValue)
//    }
    
    
    //MARK: -
    //MARK: Manage Address Book contacts
    
    // Create and add a new group to the address book database
    private func addGroup(_ name: String, fromAddressBook myAddressBook: MyAddressBook) throws {
        var sourceFound = false
        if !name.isEmpty {
            let newGroup = MyGroup.createInstance()
            newGroup.name = name
            
            // Add the new group
            try myAddressBook.addGroup(newGroup)
            
            // Get the ABSource object that contains this new group
            let groupSource = try myAddressBook.containerForGroup(newGroup)
            // Fetch the source name
            let sourceName = groupSource.name
            
            // Look for the above source among the sources in sourcesAndGroups
            for source in self.sourcesAndGroups as NSArray as! [MySource] {
                if source.name == sourceName {
                    // Associate the new group with the found source
                    source.groups.append(newGroup)
                    // Set sourceFound to YES if sourcesAndGroups already contains this source
                    sourceFound = true
                }
            }
            // Add this source to sourcesAndGroups
            if !sourceFound {
                let mutableArray = [newGroup]
                let newSource = MySource(allGroups: mutableArray, name: sourceName!)
                self.sourcesAndGroups.append(newSource)
            }
        }
    }
    
    
    // Remove a group from the given address book
    private func deleteGroup(_ group: MyGroup, fromAddressBook myAddressBook: MyAddressBook) throws {
        try myAddressBook.deleteGroup(group)
    }
    
    
    // Return a list of groups organized by sources
    private func fetchGroupsInAddressBook(_ myAddressBook: MyAddressBook) throws -> [MySource] {
        var list: [MySource] = []
        // Get all the sources from the address book
        let allSources = try myAddressBook.allContainers()
        for aSource in allSources {
            // Fetch all groups included in the current source
            let groups = try myAddressBook.allGroupsInContainer(aSource)
            // The app displays a source if and only if it contains groups
            if !groups.isEmpty {
                // Fetch the source name
                let sourceName = aSource.name!
                //Create a MySource object that contains the source name and all its groups
                let source = MySource(allGroups: groups, name: sourceName)
                
                // Save the source object into the array
                list.append(source)
            }
        }
        
        return list
    }
    
    //MARK: -
    //MARK: Table view data source
    
    // Customize the number of sections in the table view
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sourcesAndGroups.count
    }
    
    
    // Customize section header titles
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sourcesAndGroups[section].name
    }
    
    
    // Customize the number of rows in the table view
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sourcesAndGroups[section].groups.count
    }
    
    
    // Customize the appearance of table view cells.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell", for: indexPath) as UITableViewCell
        
        let source = self.sourcesAndGroups[(indexPath as NSIndexPath).section]
        let group: MyGroup = source.groups[(indexPath as NSIndexPath).row]
        cell.textLabel?.text = group.name
        
        return cell
    }
    
    
    //MARK: -
    //MARK: Editing rows
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .delete
    }
    
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        //Disable the Add button while editing
        self.navigationItem.rightBarButtonItem!.isEnabled = !editing
    }
    
    
    // Handle the deletion of a group
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let source = self.sourcesAndGroups[(indexPath as NSIndexPath).section]
            // group to be deleted
            let group = source.groups[(indexPath as NSIndexPath).row]
            
            do {
                // Remove the group from the address book
                try self.deleteGroup(group, fromAddressBook: self.addressBook)
                
                // Remove the above group from its associated source
                source.groups.remove(at: (indexPath as NSIndexPath).row)
                
                // Update the table view
                tableView.deleteRows(at: [indexPath], with: .fade)
                
                // Remove the section from the table if the associated source does not contain any groups
                if source.groups.count == 0 {
                    // Remove the source from sourcesAndGroups
                    self.sourcesAndGroups = self.sourcesAndGroups.filter{$0 !== source}
                    
                    tableView.deleteSections(IndexSet(integer: (indexPath as NSIndexPath).section),
                        with: .fade)
                }
            } catch let error {
                print(error)
            }
        }
    }
    
    
    //MARK: -
    //MARK: Memory management
    
    override func didReceiveMemoryWarning() {
        // Release the view if it doesn't have a superview.
        super.didReceiveMemoryWarning()
    }
    
    
    //MARK: -
    //MARK: Get user input
    
    // This method is called when the user taps Done in the "Add Group" view.
    @IBAction func done(_ segue: UIStoryboardSegue) {
        if segue.identifier == "returnInput" {
            if let addGroupViewController = segue.source as? AddGroupViewController {
                do {
                    try self.addGroup(addGroupViewController.group!, fromAddressBook: self.addressBook)
                    self.tableView.reloadData()
                } catch let error {
                    print(error)
                }
            }
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
    // This method is called when the user taps Cancel in the "Add Group" view.
    @IBAction func cancel(_ segue: UIStoryboardSegue) {
        if segue.identifier == "cancelInput" {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
}
