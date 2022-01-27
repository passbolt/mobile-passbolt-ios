# **PassboltPackage**

## Accounts

Contains features associated with accessing and modifying account data on device.

## AccountSetup

Module providing account setup (adding account). Includes transfer process via QR codes.

## Commons

Base extensions and functionalities used broadly in all modules.

## CommonModels

Commonly used modules and errors shared across all modules in order to allow easier communication between modules and avoid duplicates.

## Crypto

Provides PGP implementation.

## Environment

Contains all side effects and OS integration. Used to abstract and control all elements that are external to the application like randomness, time, permissions, network, storage etc. 

## Features

Defines Feature with all associated types. Provides commonly used features.

## Network client

Provides all network related functions. Contains all network request definitions with corresponding data types. Built on top of Networking from Environment.


## Passbolt app

Entrypoint for application target.

## PassboltExtension

Entrypoint for application extension target.

## Resources

Module responsible for managing all resources (passwords).

## Settings

Contains all settings and feature flags with its management and storage.

## Test extensions

Extensions commonly used in test targets. It is not included in either application or its extension.

## UICommons

Contains common UI elements like images, fonts, views and styles.


## UIComponents

Defines UIComponent with all associated types. 
