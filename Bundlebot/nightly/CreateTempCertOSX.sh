#!/bin/bash

# remove keychain
security delete-keychain temp.keychain

#security create-keychain -p testpass temp.keychain
#security import /System/Library/Keychains/SystemCACertificates.keychain -k temp.keychain -T /usr/bin/codesign
#security create-certificate-authority -k temp.keychain TestCertificate

security create-keychain -p testpass temp.keychain
security unlock-keychain -p testpass temp.keychain
openssl req -newkey rsa:2048 -nodes -keyout temp.key -x509 -days 365 -out temp.crt -subj "/CN=TestCertificate"
security import temp.key -k temp.keychain -P "" -T /usr/bin/codesign
security import temp.crt -k temp.keychain -P "" -T /usr/bin/codesign
