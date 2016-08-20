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
// compatibility wrapper classes for AddressBook/Contacts
//
//  [Caution] These wrapper classes are not intended to cover all usage of AddressBook
//  You may find many things need to be modified to use this file in your app.
//

enum MyAddressBookError: Error {
    case creation   //Unknown error in ABAddressBookCreateWithOptions
    case copy       //Error in ABAddressBookCopyPeopleWithName or ABAddressBookCopyArrayOfAllPeople
    case addValue   //Error in ABMultiValueAddValueAndLabel
    case setValue   //Error in ABRecordSetValue
    case nonMutable //CNConatct is not mutable in CNRecord
    //
    case remove
    case save
    case addRecord
    case noData
}

//MARK: ABAddressBook/CNContactStore
public class MyAddressBook: NSObject {
    private let addressBook: ABAddressBook!
    fileprivate init(addressBook: ABAddressBook?) {
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
            if let addressBook: ABAddressBook = ABAddressBookCreateWithOptions(options as CFDictionary!, &cfError)?.takeRetainedValue() {
                return MyAddressBook(addressBook: addressBook)
            } else {
                if cfError != nil {
                    let error = cfError!.takeUnretainedValue()
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
    
    public func requestAccessForContacts(_ completion: @escaping (Bool, Error?)->Void) {
        let handler: ABAddressBookRequestAccessCompletionHandler = {granted, error in
            completion(granted, error)
        }
        ABAddressBookRequestAccessWithCompletion(self.addressBook, handler)
    }
    
    public func peopleWithName(_ name: String) throws -> [MyRecord] {
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
                    return compositeName.contains(name)
                } else {
                    return false
                }
            }
            return matches.map(MyRecord.init)
        } else {
            throw MyAddressBookError.copy
        }
    }
    
    public func allContainers() throws -> [MyContainer] {
        if let allSources = ABAddressBookCopyArrayOfAllSources(addressBook)?.takeRetainedValue() {
            return (allSources as NSArray).map{MyContainer(record: $0 as ABRecord)}
        } else {
            throw MyAddressBookError.copy
        }
    }
    
    public func containerForGroup(_ group: MyGroup) throws -> MyContainer {
        if let groupSource = ABGroupCopySource(group.record)?.takeRetainedValue() {
            return MyContainer(record: groupSource)
        } else {
            throw MyAddressBookError.noData
        }
    }
    
    public func allGroupsInContainer(_ container: MyContainer) throws -> [MyGroup] {
        if let allGroups = ABAddressBookCopyArrayOfAllGroupsInSource(addressBook, container.record)?.takeRetainedValue() {
            return (allGroups as NSArray).map{MyGroup(record: $0 as ABRecord?)}
        } else {
            throw MyAddressBookError.copy
        }
    }
    
    public func deleteGroup(_ group: MyGroup) throws {
        guard ABAddressBookRemoveRecord(addressBook, group.record, nil) else {
            throw MyAddressBookError.remove
        }
        guard ABAddressBookSave(addressBook, nil) else {
            throw MyAddressBookError.save
        }
    }
    
    public func addGroup(_ group: MyGroup) throws {
        guard ABAddressBookAddRecord(addressBook, group.record, nil) else {
            throw MyAddressBookError.addRecord
        }
        guard ABAddressBookSave(addressBook, nil) else {
            throw MyAddressBookError.save
        }
    }
}
@available(iOS 9.0, *)
private class CNAddressBook: MyAddressBook {
    private let contactStore: CNContactStore
    fileprivate init(contactStore: CNContactStore) {
        self.contactStore = contactStore
        super.init(addressBook: nil)
    }
    
    override class var authorizationStatus: MyAuthorizationStatus {
        let cnAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        return MyAuthorizationStatus(cnAuthorizationStatus: cnAuthorizationStatus)
    }
    
    private override func requestAccessForContacts(_ completion: @escaping (Bool, Error?) -> Void) {
        self.contactStore.requestAccess(for: .contacts, completionHandler: completion)
    }
    
    override func peopleWithName(_ name: String) throws -> [MyRecord] {
        let predicate: NSPredicate = CNContact.predicateForContacts(matchingName: name)
        let descriptor = CNContactViewController.descriptorForRequiredKeys()
        let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: [descriptor])
        return contacts.map(CNRecord.init)
    }
    
    override func allContainers() throws -> [MyContainer] {
        let allSources = try contactStore.containers(matching: nil)
        return allSources.map{MyCNContainer(container: $0)}
    }
    
    override func containerForGroup(_ group: MyGroup) throws -> MyContainer {
        let groupIdentifier = (group as! MyCNGroup).group.identifier
        let predicate = CNContainer.predicateForContainerOfGroup(withIdentifier: groupIdentifier)
        let containers = try contactStore.containers(matching: predicate)
        if containers.isEmpty {
            throw MyAddressBookError.noData
        }
        return MyCNContainer(container: containers[0])
    }
    
    override func allGroupsInContainer(_ container: MyContainer) throws -> [MyGroup] {
        let containerIdentifier = (container as! MyCNContainer).container.identifier
        let predicate = CNGroup.predicateForGroupsInContainer(withIdentifier: containerIdentifier)
        let allGroups = try contactStore.groups(matching: predicate)
        return allGroups.map{MyCNGroup(group: $0)}
    }
    
    override func deleteGroup(_ group: MyGroup) throws {
        let mutableGroup = (group as! MyCNGroup).group.mutableCopy() as! CNMutableGroup
        let request = CNSaveRequest()
        request.delete(mutableGroup)
        try contactStore.execute(request)
    }
    
    override func addGroup(_ group: MyGroup) throws {
        let mutableGroup = (group as! MyCNGroup).group.mutableCopy() as! CNMutableGroup
        let request = CNSaveRequest()
        request.add(mutableGroup, toContainerWithIdentifier: nil)
        try contactStore.execute(request)
    }
}

//MARK: ABAuthorizationStatus/CNAuthorizationStatus
public enum MyAuthorizationStatus : Int {
    case notDetermined
    case restricted
    case denied
    case authorized
}

private extension MyAuthorizationStatus {
    init(abAuthorizationStatus: ABAuthorizationStatus) {
        switch abAuthorizationStatus {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        }
    }
    @available(iOS 9.0, *)
    init(cnAuthorizationStatus: CNAuthorizationStatus) {
        switch cnAuthorizationStatus {
        case .notDetermined: self = .notDetermined
        case .restricted: self = .restricted
        case .denied: self = .denied
        case .authorized: self = .authorized
        }
    }
}

//MARK: ABRecord(person)/CNContact
public class MyRecord: NSObject {
    private var person: ABRecord!
    fileprivate init(person: ABRecord?) {
        self.person = person
    }
    public var compositeName: String? {
        return ABRecordCopyCompositeName(person).takeRetainedValue() as String
    }
    public func appendEmail(_ mail: String, withLabel label: String) throws {
        let email: ABMutableMultiValue = ABMultiValueCreateMutable(ABPropertyType(kABStringPropertyType)).takeRetainedValue()
        guard ABMultiValueAddValueAndLabel(email, mail as CFTypeRef!, kABOtherLabel, nil) else {
            throw MyAddressBookError.addValue
        }
        var anError: Unmanaged<CFError>?
        guard ABRecordSetValue(person, ABPropertyID(kABPersonEmailProperty), email, &anError) else {
            if let error = anError?.takeRetainedValue() {
                throw error
            } else {
                throw MyAddressBookError.setValue
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
    fileprivate init(contact: CNContact) {
        self.contact = contact
        super.init(person: nil)
    }
    override var compositeName: String? {
        return CNContactFormatter.string(from: contact, style: .fullName)
    }
    override func appendEmail(_ email: String, withLabel label: String) throws {
        let newEmail = CNLabeledValue(label: label, value: email as NSString)
        guard let mutableContact = contact as? CNMutableContact else {
            throw MyAddressBookError.nonMutable
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
    case unassigned
    case local
    case exchange
    case cardDAV
}
@available(iOS 9.0,*)
extension MyContainerType {
    fileprivate init(cnContainerType: CNContainerType) {
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
                CNContainerType.unassigned.rawValue,
                CNContainerType.local.rawValue,
                CNContainerType.exchange.rawValue,
                CNContainerType.cardDAV.rawValue,
            ] == [
                MyContainerType.unassigned.rawValue,
                MyContainerType.local.rawValue,
                MyContainerType.exchange.rawValue,
                MyContainerType.cardDAV.rawValue,
            ] as [Int])
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
    let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
    if let kAddress = dlsym(RTLD_DEFAULT, "kABPersonAlternateBirthdayProperty") {
        // Alternate birthday
        //@availability(iOS, introduced=8.0)
        let kABPersonAlternateBirthdayProperty = kAddress.load(as: ABPropertyID.self)
        //print(kABPersonAlternateBirthdayProperty)
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
    fileprivate(set) public var record: MyRecord!
    private var person: ABRecord!
    private var propertyID: ABPropertyID = 0
    private var multiValueIdentifier: ABMultiValueIdentifier = 0
    fileprivate init(person: ABRecord, propertyID: ABPropertyID, multiValueIdentifier: ABMultiValueIdentifier) {
        self.person = person
        self.propertyID = propertyID
        self.multiValueIdentifier = multiValueIdentifier
        self.record = MyRecord(person: person)
    }
    fileprivate override init() {}
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
        return CNContact.localizedString(forKey: contactProperty.key)
    }
}

//MARK: ABRecord(group)/CNGroup
public class MyGroup: NSObject {
    fileprivate var _name: String
    public var name: String {
        get {return _name}
        set {
            ABRecordSetValue(record, kABGroupNameProperty, newValue as CFTypeRef!, nil)
            _name = newValue
        }
    }
    fileprivate var record: ABRecord!
    fileprivate init(record: ABRecord?) {
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
    fileprivate var record: ABRecord!
    fileprivate init(record: ABRecord) {
        self.record = record
        let sourceType = ABRecordCopyValue(record, kABSourceTypeProperty)!.takeRetainedValue() as! NSNumber
        self._type = sourceType.intValue
        super.init()
    }
    fileprivate init(record: ABRecord?) {
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
                return MyContainerType.local
            case kABSourceTypeExchange: // deprecated, used CNContainerTypeExchange
                return MyContainerType.exchange
            case kABSourceTypeCardDAV: // deprecated, use CNContainerTypeCardDAV
                return MyContainerType.cardDAV
            case kABSourceTypeCardDAVSearch, // deprecated
                kABSourceTypeExchangeGAL, // deprecated
                kABSourceTypeMobileMe, // deprecated
                kABSourceTypeLDAP: // deprecated
                fallthrough
            default:
                return MyContainerType.unassigned
            }
        }
    }
}
@available(iOS 9.0, *)
private class MyCNContainer: MyContainer {
    fileprivate var container: CNContainer
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

