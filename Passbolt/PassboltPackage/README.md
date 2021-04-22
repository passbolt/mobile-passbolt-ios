# **PassboltPackage**

Packages belong to one of four types:
- main - target for application or application extension entrypoint, contains all code and dependencies associated with that particular entrypoint
- module - group domain specific code and logical pieces of application functionalities, can have dependencies to other module, environment and essential packages
- environment - low level wrappers for side effects and external features, cannot depend on other environment packages, can depend only on essential and external packages
- essential - utilities and common functions extending language or providing fundamental functionalities required widely, cannot depend on other packages except external packages

## PassboltApp [main]
 App entrypoint, main application UI and feature integration
## PassboltExtension [main]
Autofill extension entrypoint, UI and feature integration
## Accounts [module]
Local account management (ability to add account from setup, and set current from login), access to current account (session)
## AccountSetup [module]
Account setup (transfer of keys)
## Commons [essential]
Common functions and language extensions.
## Crypto [environment]
Cryptography primitives and low level operations
## Diagnostics [module]
Application diagnostics and logs
## Features [essential]
Base for building features
## Networking [environment]
Low level network access
## NetworkClient [module]
Network client with endpoint implementation
## Resources [module]
Resource management - list, add, remove, view, edit
## Safety  [module]
High level cryptography operations in context of accounts
## Settings [module]
Application settings, feature flags 
## SignIn [module]
Account (existing) sign in 
## Storage [environment]
Database and secure store
## User [module]
Current account access (details, settings)

