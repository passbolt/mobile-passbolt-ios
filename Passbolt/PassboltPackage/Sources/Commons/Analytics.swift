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

import Darwin

// Enables debugger delay protection, naming only for slight obfuscation.
// Passbolt does not use any analytics solution.
// swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals, NoLeadingUnderscores
public func analytics() {
  #if DEBUG
  /* NOP */
  #else
  typealias _Zzw2rfadwAd = @convention(c) (Int, Int32, Int8, Int) -> Int

  let handle: UnsafeMutableRawPointer? = dlopen(
    // Path to /usr/lib/libc.dylib
    [
      47, 117, 115, 114, 47, 108, 105, 98, 47,
      108, 105, 98, 99, 46, 100, 121, 108, 105,
      98,
    ],
    RTLD_GLOBAL | RTLD_NOW
  )

  defer { dlclose(handle) }

  let ptr: UnsafeMutableRawPointer! = dlsym(
    handle,
    // ptrace
    [112, 116, 114, 97, 99, 101]
  )
  let call: _Zzw2rfadwAd = unsafeBitCast(
    ptr,
    to: _Zzw2rfadwAd.self
  )
  _ = call(31, 0, 0, 0)
  #endif
}
