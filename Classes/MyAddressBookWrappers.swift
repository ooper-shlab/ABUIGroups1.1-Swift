//
//  MyAddressBookWrappers.swift
//  ABUIGroups
//
//  Created by OOPer in cooperation with shlab.jp, on 2015/9/20.
//
//
/*
Copyright (c) 2015, OOPer(NAGATA, Atsuyuki)
All rights reserved.

Use of any parts(functions, classes or any other program language components)
of this file is permitted with no restrictions, unless you
redistribute or use this file in its entirety without modification.
In this case, providing any sort of warranties or not is the user's responsibility.

Redistribution and use in source and/or binary forms, without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

import AddressBook
//import AddressBookUI
import Contacts
import ContactsUI

//
// compatibility wrapper classes for AddressBook/Contacts and AddressBookUI/ContactsUI
//
//  [Caution] These wrapper classes are not intended to cover all usage of AddressBook/AddressBookUI.
//  You may find many things need to be modified to use this file in your app.
//

enum MyAddressBookError: ErrorType {
    case Creation   //Unknown error in ABAddressBookCreateWithOptions
    case Copy       //Error in ABAddressBookCopyPeopleWithName or ABAddressBookCopyArrayOfAllPeople
    case AddValue   //Error in ABMultiValueAddValueAndLabel
    case SetValue   //Error in ABRecordSetValue
    case NonMutable //CNConatct is not mutable in CNRecord
    //
    case Remove
    case Save
    case AddRecord
    case NoData
}

//MARK: ABAddressBook/CNContactStore
public class MyAddressBook: NSObject {
    private let addressBook: ABAddressBookRef!
    private init(addressBook: ABAddressBookRef?) {
        self.addressBook = addressBook
        setupConstants()
    }
    public class func createInstance() -> MyAddressBook {
        if #available(iOS 9.0, *) {
            let contactStore = CNContactStore()
            return CNAddressBook(contactStore: contactStore)
        } else {
            let options: [NSObject: AnyObject]? = nil
            var cfError: Unmanaged<CFError>?
            if let addressBook: ABAddressBook = ABAddressBookCreateWithOptions(options, &cfError)?.takeRetainedValue() {
                return MyAddressBook(addressBook: addressBook)
            } else {
                if cfError != nil {
                    let error = cfError!.takeUnretainedValue() as NSError
                    print(error)
                }
                return MyAddressBook(addressBook: nil)
            }
        }
    }
    
    public class var authorizationStatus: MyAuthorizationStatus {
        let abAuthorizationStatus = ABAddressBookGetAuthorizationStatus()
        return MyAuthorizationStatus(abAuthorizationStatus: abAuthorizationStatus)
    }
    
    public func requestAccessForContacts(completion: (Bool, NSError?)->Void) {
        let handler: ABAddressBookRequestAccessCompletionHandler = {granted, error in
            completion(granted, error as NSError?)
        }
        ABAddressBookRequestAccessWithCompletion(self.addressBook, handler)
    }
    
    public func peopleWithName(name: String) throws -> [MyRecord] {
        //### this does not generate the same result as CNContact.predicateForContactsMatchingName(name)
        //and the resul is not what we expect.
//        if let people = ABAddressBookCopyPeopleWithName(self.addressBook, name)?.takeRetainedValue() as NSArray? as? [ABRecord] {
//            return people.map(MyRecord.init)
//        } else {
//            throw MyAddressBookError.Copy
//        }
        if let allContacts = ABAddressBookCopyArrayOfAllPeople(self.addressBook)?.takeRetainedValue() as NSArray? as? [ABRecord] {
            let matches = allContacts.filter {record in
                if let compositeName = ABRecordCopyCompositeName(record)?.takeRetainedValue() as NSString? as? String {
                    return compositeName.containsString(name)
                } else {
                    return false
                }
            }
            return matches.map(MyRecord.init)
        } else {
            throw MyAddressBookError.Copy
        }
    }
    
    public func allContainers() throws -> [MyContainer] {
        if let allSources = ABAddressBookCopyArrayOfAllSources(addressBook)?.takeRetainedValue() {
            return (allSources as NSArray).map{MyContainer(record: $0)}
        } else {
            throw MyAddressBookError.Copy
        }
    }
    
    public func containerForGroup(group: MyGroup) throws -> MyContainer {
        if let groupSource = ABGroupCopySource(group.record)?.takeRetainedValue() {
            return MyContainer(record: groupSource)
        } else {
            throw MyAddressBookError.NoData
        }
    }
    
    public func allGroupsInContainer(container: MyContainer) throws -> [MyGroup] {
        if let allGroups = ABAddressBookCopyArrayOfAllGroupsInSource(addressBook, container.record)?.takeRetainedValue() {
            return (allGroups as NSArray).map{MyGroup(record: $0)}
        } else {
            throw MyAddressBookError.Copy
        }
    }
    
    public func deleteGroup(group: MyGroup) throws {
        guard ABAddressBookRemoveRecord(addressBook, group.record, nil) else {
            throw MyAddressBookError.Remove
        }
        guard ABAddressBookSave(addressBook, nil) else {
            throw MyAddressBookError.Save
        }
    }
    
    public func addGroup(group: MyGroup) throws {
        guard ABAddressBookAddRecord(addressBook, group.record, nil) else {
            throw MyAddressBookError.AddRecord
        }
        guard ABAddressBookSave(addressBook, nil) else {
            throw MyAddressBookError.Save
        }
    }
}
@available(iOS 9.0, *)
private class CNAddressBook: MyAddressBook {
    private let contactStore: CNContactStore
    private init(contactStore: CNContactStore) {
        self.contactStore = contactStore
        super.init(addressBook: nil)
    }
    
    override class var authorizationStatus: MyAuthorizationStatus {
        let cnAuthorizationStatus = CNContactStore.authorizationStatusForEntityType(.Contacts)
        return MyAuthorizationStatus(cnAuthorizationStatus: cnAuthorizationStatus)
    }
    
    override func requestAccessForContacts(completion: (Bool, NSError?)->Void) {
        self.contactStore.requestAccessForEntityType(.Contacts, completionHandler: completion)
    }
    
    override func peopleWithName(name: String) throws -> [MyRecord] {
        let predicate: NSPredicate = CNContact.predicateForContactsMatchingName(name)
        let descriptor = CNContactViewController.descriptorForRequiredKeys()
        let contacts = try contactStore.unifiedContactsMatchingPredicate(predicate, keysToFetch: [descriptor])
        return contacts.map(CNRecord.init)
    }
    
    override func allContainers() throws -> [MyContainer] {
        let allSources = try contactStore.containersMatchingPredicate(nil)
        return allSources.map{MyCNContainer(container: $0)}
    }
    
    override func containerForGroup(group: MyGroup) throws -> MyContainer {
        let groupIdentifier = (group as! MyCNGroup).group.identifier
        let predicate = CNContainer.predicateForContainerOfGroupWithIdentifier(groupIdentifier)
        let containers = try contactStore.containersMatchingPredicate(predicate)
        if containers.isEmpty {
            throw MyAddressBookError.NoData
        }
        return MyCNContainer(container: containers[0])
    }
    
    override func allGroupsInContainer(container: MyContainer) throws -> [MyGroup] {
        let containerIdentifier = (container as! MyCNContainer).container.identifier
        let predicate = CNGroup.predicateForGroupsInContainerWithIdentifier(containerIdentifier)
        let allGroups = try contactStore.groupsMatchingPredicate(predicate)
        return allGroups.map{MyCNGroup(group: $0)}
    }
    
    override func deleteGroup(group: MyGroup) throws {
        let mutableGroup = (group as! MyCNGroup).group.mutableCopy() as! CNMutableGroup
        let request = CNSaveRequest()
        request.deleteGroup(mutableGroup)
        try contactStore.executeSaveRequest(request)
    }
    
    override func addGroup(group: MyGroup) throws {
        let mutableGroup = (group as! MyCNGroup).group.mutableCopy() as! CNMutableGroup
        let request = CNSaveRequest()
        request.addGroup(mutableGroup, toContainerWithIdentifier: nil)
        try contactStore.executeSaveRequest(request)
    }
}

//MARK: ABAuthorizationStatus/CNAuthorizationStatus
public enum MyAuthorizationStatus : Int {
    case NotDetermined
    case Restricted
    case Denied
    case Authorized
}

private extension MyAuthorizationStatus {
    init(abAuthorizationStatus: ABAuthorizationStatus) {
        switch abAuthorizationStatus {
        case .NotDetermined: self = .NotDetermined
        case .Restricted: self = .Restricted
        case .Denied: self = .Denied
        case .Authorized: self = .Authorized
        }
    }
    @available(iOS 9.0, *)
    init(cnAuthorizationStatus: CNAuthorizationStatus) {
        switch cnAuthorizationStatus {
        case .NotDetermined: self = .NotDetermined
        case .Restricted: self = .Restricted
        case .Denied: self = .Denied
        case .Authorized: self = .Authorized
        }
    }
}

//MARK: ABPeoplePickerNavigationController/CNContactPickerViewController
/*
public class MyPeoplePickerNavigationControllerSetupper: NSObject {
    var peoplePickerNaviationController: ABPeoplePickerNavigationController?
    private init(peoplePickerNaviationController: ABPeoplePickerNavigationController?) {
        self.peoplePickerNaviationController = peoplePickerNaviationController
    }
    private override init() {
        self.peoplePickerNaviationController = ABPeoplePickerNavigationController()
    }
    ///Returns a delegateWrapper which needs to be retained while `delegate` is alive.
    public func setPickerDelegate(delegate: MyPeoplePickerNavigationControllerDelegate) -> AnyObject {
        let abDelegateWrapper = MyPeoplePickerNavigationControllerDelegateABWrapper(delegate: delegate)
        peoplePickerNaviationController!.peoplePickerDelegate = abDelegateWrapper
        return abDelegateWrapper
    }
    public var displayedPropertyKeys: [String]? {
        get {
            if let displayedProperties = peoplePickerNaviationController!.displayedProperties {
                return displayedProperties.flatMap{k2Key[$0.intValue]}
            } else {
                return nil
            }
        }
        set {
            if let keys = newValue {
                peoplePickerNaviationController!.displayedProperties = keys.flatMap{Key2k[$0].map(Int.init)}
            } else {
                peoplePickerNaviationController!.displayedProperties = nil
            }
        }
    }
    //Wrapping all functionality of UIViewController seems to be an amount of work...
    public var ViewController: UIViewController {return peoplePickerNaviationController!}
    
    class func createInstance() -> MyPeoplePickerNavigationControllerSetupper {
        if #available(iOS 9.0, *) {
            return CNPeoplePickerNavigationControllerSetupper()
        } else {
            return MyPeoplePickerNavigationControllerSetupper()
        }
    }
}
@available(iOS 9.0, *)
public class CNPeoplePickerNavigationControllerSetupper: MyPeoplePickerNavigationControllerSetupper {
    var contactPickerViewController: CNContactPickerViewController?
    private override init() {
        self.contactPickerViewController = CNContactPickerViewController()
        super.init(peoplePickerNaviationController: nil)
    }
    public override func setPickerDelegate(delegate: MyPeoplePickerNavigationControllerDelegate) -> AnyObject{
        let cnDelegateWrapper = MyPeoplePickerNavigationControllerDelegateCNWrapper(delegate: delegate)
        contactPickerViewController!.delegate = cnDelegateWrapper
        return cnDelegateWrapper
    }
    override public var displayedPropertyKeys: [String]? {
        get {
            return contactPickerViewController!.displayedPropertyKeys
        }
        set {
            contactPickerViewController!.displayedPropertyKeys = newValue
        }
    }
    override public var ViewController: UIViewController {return contactPickerViewController!}
}
*/

//MARK: ABPeoplePickerNavigationControllerDelegate
/*
@objc public protocol MyPeoplePickerNavigationControllerDelegate {
    
    // Called after a person has been selected by the user.
    //### You may need to comment in this declaration.
//    optional func peoplePickerNavigationController(peoplePicker: MyPeoplePickerNavigationController, didSelectPerson person: MyRecord)
    
    // Called after a property has been selected by the user.
    optional func peoplePickerNavigationController(peoplePicker: MyPeoplePickerNavigationControllerType, didSelectPersonProperty: MyRecordProperty)
    
    // Called after the user has pressed cancel.
    optional func peoplePickerNavigationControllerDidCancel(peoplePicker: MyPeoplePickerNavigationControllerType)
}
@objc public protocol MyPeoplePickerNavigationControllerType {
    func dismissViewControllerAnimated(animated: Bool, completion: (()->Void)?)
}
extension ABPeoplePickerNavigationController: MyPeoplePickerNavigationControllerType {}
@available(iOS 9.0, *)
extension CNContactPickerViewController: MyPeoplePickerNavigationControllerType {}
private class MyPeoplePickerNavigationControllerDelegateABWrapper: NSObject, ABPeoplePickerNavigationControllerDelegate {
    weak var delegate: MyPeoplePickerNavigationControllerDelegate!
    init(delegate: MyPeoplePickerNavigationControllerDelegate) {
        self.delegate = delegate
    }
    //### You may need to comment in this declaration.
//    @objc private func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, didSelectPerson person: ABRecord) {
//        let record = MyRecord(person: person)
//        delegate.peoplePickerNavigationController?(peoplePicker, didSelectPerson: record)
//    }
    
    @available(iOS 8.0, *)
    @objc private func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, didSelectPerson person: ABRecord, property: ABPropertyID, identifier: ABMultiValueIdentifier) {
        let recordProperty = MyRecordProperty(person: person, propertyID: property, multiValueIdentifier: identifier)
        delegate.peoplePickerNavigationController?(peoplePicker, didSelectPersonProperty: recordProperty)
    }
    //@available(iOS, introduced=2.0, deprecated=8.0)
    @objc private func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, shouldContinueAfterSelectingPerson person: ABRecord, property: ABPropertyID, identifier: ABMultiValueIdentifier) -> Bool {
        if let handler = delegate.peoplePickerNavigationController as ((MyPeoplePickerNavigationControllerType, didSelectPersonProperty: MyRecordProperty)->Void)? {
            let recordProperty = MyRecordProperty(person: person, propertyID: property, multiValueIdentifier: identifier)
            handler(peoplePicker, didSelectPersonProperty: recordProperty)
            peoplePicker.dismissViewControllerAnimated(true, completion: nil)
            return false
        } else {
            return true
        }
    }


    @objc private func peoplePickerNavigationControllerDidCancel(peoplePicker: ABPeoplePickerNavigationController) {
        delegate.peoplePickerNavigationControllerDidCancel?(peoplePicker)
    }
}
@available(iOS 9.0, *)
private class MyPeoplePickerNavigationControllerDelegateCNWrapper: NSObject, CNContactPickerDelegate {
    weak var delegate: MyPeoplePickerNavigationControllerDelegate!
    init(delegate: MyPeoplePickerNavigationControllerDelegate) {
        self.delegate = delegate
    }
    //### You may need to comment in this declaration.
//    @objc func contactPicker(picker: CNContactPickerViewController, didSelectContact contact: CNContact) {
//        let record = CNRecord(contact: contact)
//        delegate?.peoplePickerNavigationController?(picker, didSelectPerson: record)
//    }

    @objc func contactPicker(picker: CNContactPickerViewController, didSelectContactProperty contactProperty: CNContactProperty) {
        let property = CNRecordProperty(contactProperty: contactProperty)
        delegate?.peoplePickerNavigationController?(picker, didSelectPersonProperty: property)
    }

    @objc func contactPickerDidCancel(picker: CNContactPickerViewController) {
        delegate?.peoplePickerNavigationControllerDidCancel?(picker)
    }
}
*/

//MARK: ABRecord(person)/CNContact
public class MyRecord: NSObject {
    private var person: ABRecord!
    private init(person: ABRecord?) {
        self.person = person
    }
    public var compositeName: String? {
        return ABRecordCopyCompositeName(person).takeRetainedValue() as String
    }
    public func appendEmail(mail: String, withLabel label: String) throws {
        let email: ABMutableMultiValue = ABMultiValueCreateMutable(ABPropertyType(kABStringPropertyType)).takeRetainedValue()
        guard ABMultiValueAddValueAndLabel(email, mail, kABOtherLabel, nil) else {
            throw MyAddressBookError.AddValue
        }
        var anError: Unmanaged<CFError>?
        guard ABRecordSetValue(person, ABPropertyID(kABPersonEmailProperty), email, &anError) else {
            if let error = anError?.takeRetainedValue() as NSError? {
                throw error
            } else {
                throw MyAddressBookError.SetValue
            }
        }
    }
    public class func createInstance() -> MyRecord {
        if #available(iOS 9.0, *) {
            let contact = CNMutableContact()
            return CNRecord(contact: contact)
        } else {
            let person = ABPersonCreate().takeRetainedValue()
            return MyRecord(person: person)
        }
    }
}
@available(iOS 9.0, *)
private class CNRecord: MyRecord {
    private let contact: CNContact
    private init(contact: CNContact) {
        self.contact = contact
        super.init(person: nil)
    }
    override var compositeName: String? {
        return CNContactFormatter.stringFromContact(contact, style: .FullName)
    }
    override func appendEmail(email: String, withLabel label: String) throws {
        let newEmail = CNLabeledValue(label: label, value: email)
        guard let mutableContact = contact as? CNMutableContact else {
            throw MyAddressBookError.NonMutable
        }
        mutableContact.emailAddresses.append(newEmail)
    }
}
//MARK: constants
private var k2Key: [ABPropertyID: String] = [
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.givenName")
    kABPersonFirstNameProperty: MyContactGivenNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.familyName")
    kABPersonLastNameProperty: MyContactFamilyNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.middleName")
    kABPersonMiddleNameProperty: MyContactMiddleNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.namePrefix")
    kABPersonPrefixProperty: MyContactNamePrefixKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.nameSuffix")
    kABPersonSuffixProperty: MyContactNameSuffixKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.nickname")
    kABPersonNicknameProperty: MyContactNicknameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.phoneticGivenName")
    kABPersonFirstNamePhoneticProperty: MyContactPhoneticGivenNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.phoneticFamilyName")
    kABPersonLastNamePhoneticProperty: MyContactPhoneticFamilyNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.phoneticMiddleName")
    kABPersonMiddleNamePhoneticProperty: MyContactPhoneticMiddleNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.organizationName")
    kABPersonOrganizationProperty: MyContactOrganizationNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.departmentName")
    kABPersonDepartmentProperty: MyContactDepartmentNameKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.jobTitle")
    kABPersonJobTitleProperty: MyContactJobTitleKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.emailAddresses")
    kABPersonEmailProperty: MyContactEmailAddressesKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.birthday")
    kABPersonBirthdayProperty: MyContactBirthdayKey,
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.note")
    kABPersonNoteProperty: MyContactNoteKey,
    //@available(iOS, introduced=2.0, deprecated=9.0)
    //        kABPersonCreationDateProperty,
    //@available(iOS, introduced=2.0, deprecated=9.0)
    //        kABPersonModificationDateProperty,
    
    // Addresses
    //@available(iOS, introduced=2.0, deprecated=9.0, message="use CNContact.postalAddresses")
    kABPersonAddressProperty: MyContactPostalAddressesKey,
    // Dates
    kABPersonDateProperty: MyContactDatesKey,
    // Kind
    kABPersonKindProperty: MyContactTypeKey,
    // Phone numbers
    kABPersonPhoneProperty: MyContactPhoneNumbersKey,
    // IM
    kABPersonInstantMessageProperty: MyContactInstantMessageAddressesKey,
    // URLs
    kABPersonURLProperty: MyContactUrlAddressesKey,
    // Related names
    kABPersonRelatedNamesProperty: MyContactRelationsKey,
    // Social Profile
    //@availability(iOS, introduced=5.0)
    kABPersonSocialProfileProperty: MyContactSocialProfilesKey,
]
private var Key2k: [String: ABPropertyID] = [:]

public let (MyContactNamePrefixKey, MyContactGivenNameKey, MyContactMiddleNameKey, MyContactFamilyNameKey, MyContactPreviousFamilyNameKey, MyContactNameSuffixKey, MyContactNicknameKey, MyContactPhoneticGivenNameKey, MyContactPhoneticMiddleNameKey, MyContactPhoneticFamilyNameKey, MyContactOrganizationNameKey, MyContactDepartmentNameKey, MyContactJobTitleKey, MyContactBirthdayKey, MyContactNonGregorianBirthdayKey, MyContactNoteKey, MyContactImageDataKey, MyContactThumbnailImageDataKey, MyContactImageDataAvailableKey, MyContactTypeKey, MyContactPhoneNumbersKey, MyContactEmailAddressesKey, MyContactPostalAddressesKey, MyContactDatesKey, MyContactUrlAddressesKey, MyContactRelationsKey, MyContactSocialProfilesKey, MyContactInstantMessageAddressesKey) =
("namePrefix", "givenName", "middleName", "familyName", "previousFamilyName", "nameSuffix", "nickname", "phoneticGivenName", "phoneticMiddleName", "phoneticFamilyName", "organizationName", "departmentName", "jobTitle", "birthday", "nonGregorianBirthday", "note", "imageData", "thumbnailImageData", "imageDataAvailable", "contactType", "phoneNumbers", "emailAddresses", "postalAddresses", "dates", "urlAddresses", "contactRelations", "socialProfiles", "instantMessageAddresses")
// Generic labels
public let (MyLabelHome,MyLabelWork,MyLabelOther) = ("_$!<Home>!$_", "_$!<Work>!$_", "_$!<Other>!$_")

public enum MyContainerType: Int {
    case Unassigned
    case Local
    case Exchange
    case CardDAV
}
@available(iOS 9.0,*)
extension MyContainerType {
    private init(cnContainerType: CNContainerType) {
        self.init(rawValue: cnContainerType.rawValue)!
    }
}

private func setupConstants() {
    if #available(iOS 9.0, *) {
        //Some iOS9 constants are re-declared to use with iOS8, confirm all of them are valid.
        assert([
            CNContactNamePrefixKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactFamilyNameKey, CNContactPreviousFamilyNameKey, CNContactNameSuffixKey, CNContactNicknameKey, CNContactPhoneticGivenNameKey, CNContactPhoneticMiddleNameKey, CNContactPhoneticFamilyNameKey, CNContactOrganizationNameKey, CNContactDepartmentNameKey, CNContactJobTitleKey, CNContactBirthdayKey, CNContactNonGregorianBirthdayKey, CNContactNoteKey, CNContactImageDataKey, CNContactThumbnailImageDataKey, CNContactImageDataAvailableKey, CNContactTypeKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey, CNContactDatesKey, CNContactUrlAddressesKey, CNContactRelationsKey, CNContactSocialProfilesKey, CNContactInstantMessageAddressesKey
            ] == [
                MyContactNamePrefixKey, MyContactGivenNameKey, MyContactMiddleNameKey, MyContactFamilyNameKey, MyContactPreviousFamilyNameKey, MyContactNameSuffixKey, MyContactNicknameKey, MyContactPhoneticGivenNameKey, MyContactPhoneticMiddleNameKey, MyContactPhoneticFamilyNameKey, MyContactOrganizationNameKey, MyContactDepartmentNameKey, MyContactJobTitleKey, MyContactBirthdayKey, MyContactNonGregorianBirthdayKey, MyContactNoteKey, MyContactImageDataKey, MyContactThumbnailImageDataKey, MyContactImageDataAvailableKey, MyContactTypeKey, MyContactPhoneNumbersKey, MyContactEmailAddressesKey, MyContactPostalAddressesKey, MyContactDatesKey, MyContactUrlAddressesKey, MyContactRelationsKey, MyContactSocialProfilesKey, MyContactInstantMessageAddressesKey
            ])
        assert([CNLabelHome,CNLabelWork,CNLabelOther] == [MyLabelHome,MyLabelWork,MyLabelOther])
        //
        assert([
                CNContainerType.Unassigned.rawValue,
                CNContainerType.Local.rawValue,
                CNContainerType.Exchange.rawValue,
                CNContainerType.CardDAV.rawValue,
            ] == [
                MyContainerType.Unassigned.rawValue,
                MyContainerType.Local.rawValue,
                MyContainerType.Exchange.rawValue,
                MyContainerType.CardDAV.rawValue,
            ])
    }
    assert([kABHomeLabel as String,
        kABWorkLabel as String,
        kABOtherLabel as String] == [MyLabelHome,MyLabelWork,MyLabelOther])

    //### It seems current availability checking feature does not work well for constant references.
//    if #available(iOS 8.0, *) {
//        // Alternate birthday
//        //@availability(iOS, introduced=8.0)
//        k2Key[kABPersonAlternateBirthdayProperty] = MyContactNonGregorianBirthdayKey
//    }
    //### An example not-working in iOS 7.
//    if #available(iOS 8.0, *) {
//        k2Key[iOS8Constants.kABPersonAlternateBirthdayProperty] = MyContactNonGregorianBirthdayKey
//    }
    //### `Just works` code for iOS 7..9.
    //Using dlsym is not recommended, let's hope this will work until we have no need to support iOS 7.
    let RTLD_DEFAULT = UnsafeMutablePointer<Void>(bitPattern: -2)
    if dlsym(RTLD_DEFAULT, "kABPersonAlternateBirthdayProperty") != nil {
        // Alternate birthday
        //@availability(iOS, introduced=8.0)
        let kAddress = dlsym(RTLD_DEFAULT, "kABPersonAlternateBirthdayProperty")
        let kABPersonAlternateBirthdayProperty = UnsafePointer<ABPropertyID>(kAddress).memory
        print(kABPersonAlternateBirthdayProperty)
        k2Key[kABPersonAlternateBirthdayProperty] = MyContactNonGregorianBirthdayKey
    }
    for (k, Key) in k2Key {
        Key2k[Key] = k
    }
    
}
//### An example not-working in iOS 7.
//@available(iOS 8.0, *)
//private struct iOS8Constants {
//    static let kABPersonAlternateBirthdayProperty = AddressBook.kABPersonAlternateBirthdayProperty
//}

//MARK: CNContactProperty
public class MyRecordProperty: NSObject {
    private(set) public var record: MyRecord!
    private var person: ABRecord!
    private var propertyID: ABPropertyID = 0
    private var multiValueIdentifier: ABMultiValueIdentifier = 0
    private init(person: ABRecord, propertyID: ABPropertyID, multiValueIdentifier: ABMultiValueIdentifier) {
        self.person = person
        self.propertyID = propertyID
        self.multiValueIdentifier = multiValueIdentifier
        self.record = MyRecord(person: person)
    }
    private override init() {}
    public var localizedPropertyName: String {
        return ABPersonCopyLocalizedPropertyName(propertyID).takeRetainedValue() as String
    }
}
@available(iOS 9.0, *)
private class CNRecordProperty: MyRecordProperty {
    let contactProperty: CNContactProperty
    init(contactProperty: CNContactProperty) {
        self.contactProperty = contactProperty
        super.init()
        self.record = CNRecord(contact: contactProperty.contact)
    }
    override var localizedPropertyName: String {
        return CNContact.localizedStringForKey(contactProperty.key)
    }
}

//MARK: ABRecord(group)/CNGroup
public class MyGroup: NSObject {
    private var _name: String
    public var name: String {
        get {return _name}
        set {
            ABRecordSetValue(record, kABGroupNameProperty, newValue, nil)
            _name = newValue
        }
    }
    private var record: ABRecord!
    private init(record: ABRecord?) {
        self.record = record
        self._name = (ABRecordCopyCompositeName(record)?.takeRetainedValue() as String?) ?? ""
        super.init()
    }
    
    ///Creates mutable instance
    class func createInstance() -> MyGroup {
        if #available(iOS 9.0, *) {
            let newGroup = CNMutableGroup()
            return MyCNGroup(group: newGroup)
        } else {
            let newGroup: ABRecord = ABGroupCreate()!.takeRetainedValue()
            return MyGroup(record: newGroup)
        }
    }
}
@available(iOS 9.0, *)
private class MyCNGroup: MyGroup {
    let group: CNGroup
    init(group: CNGroup) {
        self.group = group
        super.init(record: nil)
        self._name = group.name
    }
    override var name: String {
        get {return group.name}
        set {
            (group as! CNMutableGroup).name = newValue
        }
    }
}

//MARK: ABRecord(source)/CNContainer
public class MyContainer: NSObject {
    private var _name: String?
    private var _type: Int = 0
    private var record: ABRecord!
    private init(record: ABRecord) {
        self.record = record
        let sourceType = ABRecordCopyValue(record, kABSourceTypeProperty)!.takeRetainedValue() as! NSNumber
        self._type = sourceType.integerValue
        super.init()
    }
    private init(record: ABRecord?) {
        self.record = record
        super.init()
    }
    public var name: String? {
        get {
            //### Why don't use kABSourceNameProperty?
            switch _type {
            case kABSourceTypeLocal:
                return "On My Device"
            case kABSourceTypeExchange:
                return "Exchange server"
            case kABSourceTypeExchangeGAL:
                return "Exchange Global Address List"
            case kABSourceTypeMobileMe:
                return "MobileMe"
            case kABSourceTypeLDAP:
                return "LDAP server"
            case kABSourceTypeCardDAV:
                return "CardDAV server"
            case kABSourceTypeCardDAVSearch:
                return "Searchable CardDAV server"
            default:
                break
            }
            return nil
        }
    }
    public var type: MyContainerType {
        get {
            switch _type {
            case kABSourceTypeLocal: // deprecated, use CNContainerTypeLocal
                return MyContainerType.Local
            case kABSourceTypeExchange: // deprecated, used CNContainerTypeExchange
                return MyContainerType.Exchange
            case kABSourceTypeCardDAV: // deprecated, use CNContainerTypeCardDAV
                return MyContainerType.CardDAV
            case kABSourceTypeCardDAVSearch, // deprecated
                kABSourceTypeExchangeGAL, // deprecated
                kABSourceTypeMobileMe, // deprecated
                kABSourceTypeLDAP: // deprecated
                fallthrough
            default:
                return MyContainerType.Unassigned
            }
        }
    }
}
@available(iOS 9.0, *)
private class MyCNContainer: MyContainer {
    private var container: CNContainer
    init(container: CNContainer) {
        self.container = container
        super.init(record: nil)
    }
    override var name: String? {
        get {
            return container.name
        }
    }
    override var type: MyContainerType {
        get {
            return MyContainerType(cnContainerType: container.type)
        }
    }
}
//MARK: ABPersonViewController/CNContactViewController(forContact:)
/*
public class MyPersonViewControllerSetupperFactory {
    class func createInstanceForPerson(record: MyRecord) -> MyPersonViewControllerSetupper {
        if #available(iOS 9.0, *) {
            let contact = (record as! CNRecord).contact
            return CNContactViewControllerSetupperForContact(contact: contact)
        } else {
            return MyPersonViewControllerSetupper(person: record.person)
        }
    }
    class func createInstanceForNewPerson() -> MyNewPersonViewControllerSetupper {
        if #available(iOS 9.0, *) {
            return CNContactViewControllerSetupperForNewContact()
        } else {
            return MyNewPersonViewControllerSetupper()
        }
    }
    class func createInstanceForUnknownPerson(record: MyRecord) -> MyUnknownPersonViewControllerSetupper {
        if #available(iOS 9.0, *) {
            let contact = (record as! CNRecord).contact
            return CNContactViewControllerSetupperForUnknownContact(contact: contact)
        } else {
            let controller = MyUnknownPersonViewControllerSetupper(person: record.person)
            return controller
        }
    }
}
public class MyPersonViewControllerSetupper: NSObject {
    let abPersonViewController: ABPersonViewController!
    ///Returns a delegateWrapper which needs to be retained while `delegate` is alive.
    private init(abPersonViewController: ABPersonViewController?) {
        self.abPersonViewController = abPersonViewController
        super.init()
    }
    private init(person: ABRecord) {
        self.abPersonViewController = ABPersonViewController()
        super.init()
        self.abPersonViewController.displayedPerson = person
    }
    public func setPersonDelegate(delegate: MyPersonViewControllerDelegate) -> AnyObject {
        let delegateWrapper = MyPersonViewControllerDelegateABWrapper(delegate: delegate)
        abPersonViewController.personViewDelegate = delegateWrapper
        return delegateWrapper
    }
    public var allowsEditing: Bool {
        get {
            return abPersonViewController.allowsEditing
        }
        set {
            abPersonViewController.allowsEditing = newValue
        }
    }
    
    public var ViewController: UIViewController {
        return abPersonViewController
    }
}
@available(iOS 9.0, *)
private class CNContactViewControllerSetupperForContact: MyPersonViewControllerSetupper {
    let cnPersonViewController: CNContactViewController
    init(contact: CNContact) {
        self.cnPersonViewController = CNContactViewController(forContact: contact)
        super.init(abPersonViewController: nil)
    }
    override func setPersonDelegate(delegate: MyPersonViewControllerDelegate) -> AnyObject {
        let delegateWrapper = MyPersonViewControllerDelegateCNWrapper(personDelegate: delegate)
        cnPersonViewController.delegate = delegateWrapper
        return delegateWrapper
    }
    override var allowsEditing: Bool {
        get {
            return cnPersonViewController.allowsEditing
        }
        set {
            cnPersonViewController.allowsEditing = newValue
        }
    }
    
    override var ViewController: UIViewController {
        return cnPersonViewController
    }
}
*/

//MARK: ABNewPersonViewControllerDelegate/CNContactViewControllerDelegate
/*
@objc public protocol MyPersonViewControllerType {}
extension ABPersonViewController: MyPersonViewControllerType {}
@available(iOS 9.0, *)
extension CNContactViewController: MyPersonViewControllerType {}
public protocol MyPersonViewControllerDelegate: class {
    
    // Called when the user selects an individual value in the Person view, identifier will be kABMultiValueInvalidIdentifier if a single value property was selected.
    // Return NO if you do not want anything to be done or if you are handling the actions yourself.
    // Return YES if you want the ABPersonViewController to perform its default action.
    func personViewController(personViewController: MyPersonViewControllerType, shouldPerformDefaultActionForProperty: MyRecordProperty) -> Bool
    
}
private class MyPersonViewControllerDelegateABWrapper: NSObject, ABPersonViewControllerDelegate {
    weak var delegate: MyPersonViewControllerDelegate?
    init(delegate: MyPersonViewControllerDelegate) {
        self.delegate = delegate
    }
    @objc private func personViewController(personViewController: ABPersonViewController, shouldPerformDefaultActionForPerson person: ABRecord, property: ABPropertyID, identifier: ABMultiValueIdentifier) -> Bool {
        let recordProperty = MyRecordProperty(person: person, propertyID: property, multiValueIdentifier: identifier)
        return delegate?.personViewController(personViewController, shouldPerformDefaultActionForProperty: recordProperty) ?? true
    }
}
@available(iOS 9.0, *)
private class MyPersonViewControllerDelegateCNWrapper: NSObject, CNContactViewControllerDelegate {
    weak var personDelegate: MyPersonViewControllerDelegate?
    init(personDelegate: MyPersonViewControllerDelegate) {
        self.personDelegate = personDelegate
    }
    @objc private func contactViewController(viewController: CNContactViewController, didCompleteWithContact contact: CNContact?) {
        //
    }
    @objc private func contactViewController(viewController: CNContactViewController, shouldPerformDefaultActionForContactProperty property: CNContactProperty) -> Bool {
        let recordProperty = CNRecordProperty(contactProperty: property)
        return personDelegate?.personViewController(viewController, shouldPerformDefaultActionForProperty: recordProperty) ?? true
    }
}
*/

//MARK: ABNewPersonViewController
/*
public class MyNewPersonViewControllerSetupper: NSObject {
    private let abNewPersonViewController: ABNewPersonViewController!
    private init(abNewPersonViewController: ABNewPersonViewController?) {
        self.abNewPersonViewController = abNewPersonViewController
        super.init()
    }
    private override init() {
        self.abNewPersonViewController = ABNewPersonViewController()
        super.init()
    }
    ///Returns a delegateWrapper which needs to be retained while `delegate` is alive.
    public func setNewPersonDelegate(delegate: MyNewPersonViewControllerDelegate)->AnyObject {
        let delegateWrapper = MyNewPersonViewControllerDelegateABWrapper(delegate: delegate)
        abNewPersonViewController.newPersonViewDelegate = delegateWrapper
        return delegateWrapper
    }
    
    public var ViewController: UIViewController {
        return abNewPersonViewController
    }
}
@available(iOS 9.0, *)
private class CNContactViewControllerSetupperForNewContact: MyNewPersonViewControllerSetupper {
    let cnNewPersonViewController: CNContactViewController
    override init() {
        self.cnNewPersonViewController = CNContactViewController(forNewContact: nil)
        super.init(abNewPersonViewController: nil)
    }
    override func setNewPersonDelegate(delegate: MyNewPersonViewControllerDelegate)->AnyObject {
        let delegateWrapper = MyNewPersonViewControllerDelegateCNWrapper(newPersonDelegate: delegate)
        cnNewPersonViewController.delegate = delegateWrapper
        return delegateWrapper
    }
    
    override var ViewController: UIViewController {
        return cnNewPersonViewController
    }
}
*/

//MARK: ABNewPersonViewControllerDelegate/CNContactViewControllerDelegate
/*
@objc public protocol MyNewPersonViewControllerType {}
extension ABNewPersonViewController: MyNewPersonViewControllerType {}
@available(iOS 9.0, *)
extension CNContactViewController: MyNewPersonViewControllerType {}
public protocol MyNewPersonViewControllerDelegate: class {
    
    // Called when the user selects Save or Cancel. If the new person was saved, person will be
    // a valid person that was saved into the Address Book. Otherwise, person will be NULL.
    // It is up to the delegate to dismiss the view controller.
    func newPersonViewController(newPersonView: MyNewPersonViewControllerType, didCompleteWithNewPerson record: MyRecord?)
    
}
private class MyNewPersonViewControllerDelegateABWrapper: NSObject, ABNewPersonViewControllerDelegate {
    weak var delegate: MyNewPersonViewControllerDelegate?
    init(delegate: MyNewPersonViewControllerDelegate) {
        self.delegate = delegate
    }
    @objc private func newPersonViewController(newPersonView: ABNewPersonViewController, didCompleteWithNewPerson person: ABRecord?) {
        let record = MyRecord(person: person)
        delegate?.newPersonViewController(newPersonView, didCompleteWithNewPerson: record)
    }
}
@available(iOS 9.0, *)
private class MyNewPersonViewControllerDelegateCNWrapper: NSObject, CNContactViewControllerDelegate {
    weak var newPersonDelegate: MyNewPersonViewControllerDelegate?
    init(newPersonDelegate: MyNewPersonViewControllerDelegate) {
        self.newPersonDelegate = newPersonDelegate
    }
    @objc private func contactViewController(viewController: CNContactViewController, didCompleteWithContact contact: CNContact?) {
        let record = contact.map(CNRecord.init)
        newPersonDelegate?.newPersonViewController(viewController, didCompleteWithNewPerson: record)
    }
    @objc private func contactViewController(viewController: CNContactViewController, shouldPerformDefaultActionForContactProperty property: CNContactProperty) -> Bool {
        return true
    }
}
*/

//MARK: ABUnknownPersonViewController
/*
@objc public class MyUnknownPersonViewControllerSetupper: NSObject {
    private let abUnknownPersonViewController: ABUnknownPersonViewController!
    private init(abUnknownPersonViewController: ABUnknownPersonViewController?) {
        self.abUnknownPersonViewController = abUnknownPersonViewController
        super.init()
    }
    private convenience init(person: ABRecord) {
        self.init(abUnknownPersonViewController: ABUnknownPersonViewController())
        self.abUnknownPersonViewController.displayedPerson = person
    }
    ///Returns a delegateWrapper which needs to be retained while `delegate` is alive.
    @objc public func setUnknownPersonDelegate(delegate: MyUnknownPersonViewControllerDelegate)->AnyObject {
        let delegateWrapper = MyUnknownPersonViewControllerDelegateABWrapper(delegate: delegate)
        abUnknownPersonViewController.unknownPersonViewDelegate = delegateWrapper
        return delegateWrapper
    }
    public func allowsEditing(allows: Bool, forAddressBook addressBook: MyAddressBook) {
        abUnknownPersonViewController.addressBook = addressBook.addressBook
        abUnknownPersonViewController.allowsAddingToAddressBook = allows
    }
    public var allowsActions: Bool {
        get {
            return abUnknownPersonViewController.allowsActions
        }
        set {
            abUnknownPersonViewController.allowsActions = newValue
        }
    }
    public var alternateName: String? {
        get {
            return abUnknownPersonViewController.alternateName
        }
        set {
            abUnknownPersonViewController.alternateName = newValue
        }
    }
    public var title: String? {
        get {
            return abUnknownPersonViewController.title
        }
        set {
            abUnknownPersonViewController.title = newValue
        }
    }
    public var message: String? {
        get {
            return abUnknownPersonViewController.message
        }
        set {
            abUnknownPersonViewController.message = newValue
        }
    }
    
    public var ViewController: UIViewController {
        return abUnknownPersonViewController
    }
}
@available(iOS 9.0, *)
private class CNContactViewControllerSetupperForUnknownContact: MyUnknownPersonViewControllerSetupper {
    private let cnUnknownPersonViewController: CNContactViewController
    private init(contact: CNContact) {
        self.cnUnknownPersonViewController = CNContactViewController(forUnknownContact: contact)
        super.init(abUnknownPersonViewController: nil)
    }
    override func setUnknownPersonDelegate(delegate: MyUnknownPersonViewControllerDelegate)->AnyObject {
        let delegateWrapper = MyUnknownPersonViewControllerDelegateCNWrapper(unknownPersonDelegate: delegate)
        cnUnknownPersonViewController.delegate = delegateWrapper
        return delegateWrapper
    }
    override func allowsEditing(allows: Bool, forAddressBook addressBook: MyAddressBook) {
        cnUnknownPersonViewController.contactStore = (addressBook as! CNAddressBook).contactStore
        cnUnknownPersonViewController.allowsEditing = allows
    }
    override var allowsActions: Bool {
        get {
            return cnUnknownPersonViewController.allowsActions
        }
        set {
            cnUnknownPersonViewController.allowsActions = newValue
        }
    }
    override var alternateName: String? {
        get {
            return cnUnknownPersonViewController.alternateName
        }
        set {
            cnUnknownPersonViewController.alternateName = newValue
        }
    }
    override var title: String? {
        get {
            return cnUnknownPersonViewController.title
        }
        set {
            cnUnknownPersonViewController.title = newValue
        }
    }
    override var message: String? {
        get {
            return cnUnknownPersonViewController.message
        }
        set {
            cnUnknownPersonViewController.message = newValue
        }
    }
    
    override var ViewController: UIViewController {
        return cnUnknownPersonViewController
    }
}
*/

//MARK: ABUnknownPersonViewControllerDelegate/CNContactViewControllerDelegate
/*
@objc public protocol MyUnknownPersonViewControllerType {}
extension ABUnknownPersonViewController: MyUnknownPersonViewControllerType {}
@available(iOS 9.0, *)
extension CNContactViewController: MyUnknownPersonViewControllerType {}
@objc public protocol MyUnknownPersonViewControllerDelegate {
    
    // Called when picking has completed.  If picking was canceled, 'person' will be NULL.
    // Otherwise, person will be either a non-NULL resolved contact, or newly created and
    // saved contact, in both cases, person will be a valid contact in the Address Book.
    // It is up to the delegate to dismiss the view controller.
    func unknownPersonViewController(unknownCardViewController: MyUnknownPersonViewControllerType, didResolveToPerson record: MyRecord?);
    
    // Called when the user selects an individual value in the unknown person view, identifier will be kABMultiValueInvalidIdentifier if a single value property was selected.
    // Return NO if you do not want anything to be done or if you are handling the actions yourself.
    // Return YES if you want the ABUnknownPersonViewController to perform its default action.
    optional func unknownPersonViewController(personViewController: MyUnknownPersonViewControllerType, shouldPerformDefaultActionForProperty: MyRecordProperty) -> Bool
    
}
private class MyUnknownPersonViewControllerDelegateABWrapper: NSObject, ABUnknownPersonViewControllerDelegate {
    weak var delegate: MyUnknownPersonViewControllerDelegate?
    init(delegate: MyUnknownPersonViewControllerDelegate) {
        self.delegate = delegate
    }
    @objc private func unknownPersonViewController(personViewController: ABUnknownPersonViewController, shouldPerformDefaultActionForPerson person: ABRecord, property: ABPropertyID, identifier: ABMultiValueIdentifier) -> Bool {
        let recordProperty = MyRecordProperty(person: person, propertyID: property, multiValueIdentifier: identifier)
        return delegate?.unknownPersonViewController?(personViewController, shouldPerformDefaultActionForProperty: recordProperty) ?? true
    }
    @objc private func unknownPersonViewController(unknownCardViewController: ABUnknownPersonViewController, didResolveToPerson person: ABRecord?) {
        let record = MyRecord(person: person)
        delegate?.unknownPersonViewController(unknownCardViewController, didResolveToPerson: record)
    }
}
@available(iOS 9.0, *)
private class MyUnknownPersonViewControllerDelegateCNWrapper: NSObject, CNContactViewControllerDelegate {
    weak var unknownPersonDelegate: MyUnknownPersonViewControllerDelegate?
    init(unknownPersonDelegate: MyUnknownPersonViewControllerDelegate) {
        self.unknownPersonDelegate = unknownPersonDelegate
    }
    @objc private func contactViewController(viewController: CNContactViewController, didCompleteWithContact contact: CNContact?) {
        let record = contact.map(CNRecord.init)
        unknownPersonDelegate?.unknownPersonViewController(viewController, didResolveToPerson: record)
    }
    @objc private func contactViewController(viewController: CNContactViewController, shouldPerformDefaultActionForContactProperty property: CNContactProperty) -> Bool {
        let recordProperty = CNRecordProperty(contactProperty: property)
        return unknownPersonDelegate?.unknownPersonViewController?(viewController, shouldPerformDefaultActionForProperty: recordProperty) ?? true
    }
}
*/