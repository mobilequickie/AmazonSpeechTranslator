/*
Copyright 2018 Dennis Hills.

Licensed under the Apache License, Version 2.0 (the "License").
You may not use this file except in compliance with the License.
A copy of the License is located at

http://www.apache.org/licenses/LICENSE-2.0

or in the "license" file accompanying this file. This file is distributed
on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
express or implied. See the License for the specific language governing
permissions and limitations under the License.
*/

//  AppDelegate.swift
//  SpeechRec
//
//  Description:
//  This is a demo iOS Swift app that recognizes your voice and converts it to text. That text is then translated into another language and read back to you in the current language of the text.
//
//  Features:
//  1. Demonstrates on-device speech-to-text (using Apple Speech API)
//  2. Translates the transcribed text to a language of your your choice using Amazon Translate
//  3. Provides text-to-speech option that will read the text to you in the language of the currently translated text.
//
//  Depedencies:
//  Amazon Cognito (Identity Pool) - For auth
//  Amazon Translate SDK - Translates our transcribed text to language of choice
//  AWS Polly SDK - Sending text directly to Amazon Polly to playback the audio of translated text in the appropriate voice
//
//  Services/APIs Used:
//  Apple Speech API, Amazon Cognito, Amazon Translate, and Amazon Polly

//  App Flow:
//  Apple Speech Recognizer (Voice) -> Text (English or Locale) -> Amazon Translate -> App (as translated text) -> Amazon Polly (as text) -> Playback synthesized voice stream from Polly as MP3 to app
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}
}

