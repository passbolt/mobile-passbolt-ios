//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import AegithalosCocoa

extension ImageNameConstant {
  
  public static let appLogo: Self = "AppLogo"
  public static var navigationBarPlaceholder: Self { "NavigationBarPlaceholder" }
  public static var arrowLeft: Self { "ArrowLeft" }
  public static var help: Self { "Help" }
  public static var person: Self { "Person" }
  public static var homeTab: Self { "HomeTab" }
  public static var settingsTab: Self { "SettingsTab" }
}

extension DynamicImage {
  
  // swiftlint:disable force_unwrapping
  public static var qrCodeSample: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "QrCodeSample",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "QrCodeSample",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var successMark: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "successMark",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "successMark",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var failureMark: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "failureMark",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "failureMark",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var faceID: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "FaceID",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "FaceID",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var faceIDSetup: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "FaceIDSetup",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "FaceIDSetup",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var touchID: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "TouchID",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "TouchID",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var touchIDSetup: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "TouchIDSetup",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "TouchIDSetup",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var keychainIcon: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "KeychainIcon",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "KeychainIcon",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var keyboardIcon: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "KeyboardIcon",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "KeyboardIcon",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var settingsIcon: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "SettingsIcon",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "SettingsIcon",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var switchIcon: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "SwitchIcon",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "SwitchIcon",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  
  public static var passboltIcon: Self {
    Self { userInterfaceStyle in
      switch userInterfaceStyle {
      case .dark:
        return UIImage(
          named: "PassboltIcon",
          in: .uiCommons,
          with: nil
        )!
        
      case .light, _:
        return UIImage(
          named: "PassboltIcon",
          in: .uiCommons,
          with: nil
        )!
      }
    }
  }
  // swiftlint:enable force_unwrapping
}
