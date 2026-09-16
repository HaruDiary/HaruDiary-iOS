//
//  DataModel.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/23/24.
//
import CoreLocation
import Foundation
import UIKit

// 사진 & 메타데이터를 FirebaseStorage에 저장하기 위한 Struct
struct ImageLocationInfo {
    var image: UIImage
    var locationInfo: LocationInfo?
    var assetIdentifier: String?
    var captureTime: String?
    var location: String?
}
struct LocationInfo {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
}

enum CellModel {
    case profileItem(email: String, name: String, image: String?, isLoggedIn: Bool)
    case settingItem(title: String, iconImage: String, number:Int)
    case signOutItem(title: String, iconImage: String, number:Int, isLoggedIn: Bool)
}

enum AlertCellModel : Equatable {
    case switchItem(title: String, image: String, switchStatus: Bool)
    case dateItem(title: String, image: String, label: String, switchStatus: Bool, isExpanded: Bool)
    case timePicker
    case dayItem(title: String, isSelected: Bool)
}

struct OnboardingModel : Equatable {
    var descriptionImage : String
    var descriptionLabel : String
}
