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

import UIKit
import Speech
import AWSTranslate
import AWSPolly
import AWSMobileClient
import AVKit
import Foundation
import CoreGraphics
import DropDown

class ViewController: UIViewController, AVAudioRecorderDelegate {
    
    @IBOutlet weak var lblLocale: UILabel!
    @IBOutlet weak var translatedTextView: UITextView!
    @IBOutlet weak var transcribedTextView: UITextView!
    @IBOutlet weak var btnLanguage: UIButton!
    @IBOutlet weak var btnRecord: UIButton!
    @IBOutlet weak var recordView: UIImageView!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    // Used to playback audio from Polly
    var recordingSession: AVAudioSession!
    var audioPlayer = AVPlayer()
    
    // Spoken Text
    var spokenText: String!
    var destinationLanguage: String!
    
    // UI Properties
    var recordButton: UIButton!
    var outputLabel: UILabel!
    
    // Is the app listening flag
    var isListening = false
    
    // Pulsator
    let pulsator = Pulsator()
    
    // Language code
    let langCode = Locale.current.languageCode
    
    // DropDown for languages
    let dropDown = DropDown()
    let languageImageView = UIImageView()
    
    // Speech stuff
    let speechRecognizer = SFSpeechRecognizer()!
    let audioEngine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask?
    
    var status = SpeechStatus.ready {
        didSet {
            //self.setUI(status: status)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            if let userState = userState {
                print("UserState: \(userState.rawValue)")
            } else if let error = error {
                print("error: \(error.localizedDescription)")
            }
        }
        
        // #Service Configuration#
        let serviceConfiguration = AWSServiceConfiguration(region: .USWest2, credentialsProvider: AWSMobileClient.sharedInstance())
        
        // #Service Manager#
        AWSServiceManager.default().defaultServiceConfiguration = serviceConfiguration
        
        spinner.hidesWhenStopped = true
        
        // Display the source language as the user's default language of the device
        if let languageCode = langCode {
            lblLocale.text = Locale.current.localizedString(forIdentifier: languageCode)
        } else {
            lblLocale.text = "English"
        }
        
        // Check authorization for listening/recording audio on the device
        switch SFSpeechRecognizer.authorizationStatus() {
            case .notDetermined:
                askSpeechPermission()
            case .authorized:
                self.status = .ready
            case .denied, .restricted:
                self.status = .unavailable
        }
        
        // Initialize audio session
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            try recordingSession.setActive(true)
        } catch  {
            print("Exception setting up recordingSession")
        }
        
        setupLanguageDropDown() // Setup the dropdown of supported destination languages
        initializeTextViews() // Initialize the design for the transcribed and translated text views
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setPulsator() // Setup Pulsator location under the live listener button within recordView (ImageView)
    }
    
    func initializeTextViews() {
        // Prettify the transcribed and translated text views
        transcribedTextView.layer.borderColor = UIColor.lightGray.cgColor
        transcribedTextView.layer.borderWidth = 1.0
        transcribedTextView.layer.cornerRadius = 5;
        translatedTextView.layer.borderColor = UIColor.lightGray.cgColor
        translatedTextView.layer.borderWidth = 1.0
        translatedTextView.layer.cornerRadius = 5;
        
        var transcribedLanguageImage = ""
        var translatedLanguageImage = ""
        
        // Setting the background image in the transcribed text view based on the source language (based on the device locale)
        guard let languageCode = langCode else { return }
        
        if (languageCode == "en") { // Default
            transcribedLanguageImage = "English.png"
        } else {
            switch languageCode {
            case "fr":
                transcribedLanguageImage = "French.png"
            case "de":
                transcribedLanguageImage = "German.png"
            case "pt":
                transcribedLanguageImage = "Portuguese.png"
            case "es":
                transcribedLanguageImage = "Spanish.png"
            default:
                transcribedLanguageImage = ""
            }
        }
        
        if dropDown.selectedItem != nil {
            translatedLanguageImage = dropDown.selectedItem! + ".png"
        }
        else {
            translatedLanguageImage = "Spanish.png"
        }
        
        // English
        let defaultImg = UIImageView(frame: transcribedTextView.bounds)
        defaultImg.image = UIImage(named: transcribedLanguageImage)
        transcribedTextView.backgroundColor = UIColor.clear
        transcribedTextView.addSubview(defaultImg)
        transcribedTextView.sendSubview(toBack: defaultImg)
        
        //Default translated to language
        languageImageView.frame = translatedTextView.bounds
        languageImageView.image = UIImage(named: translatedLanguageImage)
        translatedTextView.backgroundColor = UIColor.clear
        translatedTextView.addSubview(languageImageView)
        translatedTextView.sendSubview(toBack: languageImageView)
    }
    
    func setupLanguageDropDown() {
        dropDown.anchorView = btnLanguage
        
        if(langCode != "en") {
            dropDown.dataSource = ["English"] // Polly only supports English destination language if the source is anything but English
            dropDown.selectRow(at: 0) // Set default language dropdown to "English"
        } else {
            dropDown.dataSource = ["Dutch", "French", "German", "Italian", "Japanese", "Polish", "Portuguese", "Spanish"] // Polly supports 4 of 7 Amazon Translate languages (May 2018)
            dropDown.selectRow(at: 7) // Set default language dropdown to "Spanish"
        }
        
        let item = dropDown.selectedItem
        self.btnLanguage.setTitle(item, for: UIControlState.normal) // The language dropdown is a UIButton and displays the currently selected language
        destinationLanguage = item
        
        // Action triggered on selection
        dropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            print("Selected language: \(item)")
            self.btnLanguage.setTitle(item, for: UIControlState.normal)
            self.destinationLanguage = item
            
            // Remove the existing imageView to make way for the new language imageView background
            self.languageImageView.removeFromSuperview()
            self.translatedTextView.text = "..."
            
            // Update image background of the translated textView with the current language
            self.languageImageView.image = UIImage(named: item + ".png")
            self.translatedTextView.backgroundColor = UIColor.clear
            self.translatedTextView.addSubview(self.languageImageView)
            self.translatedTextView.sendSubview(toBack: self.languageImageView)
            
            self.translateText(spokenText: self.transcribedTextView.text, targetLanguage: item)
        }
    }
    
    @IBAction func btnShowLanguages(_ sender: Any) {
         dropDown.show()
    }
    
    @IBAction func record(_ sender: Any) {
        if !isListening {
            do {
                try startListening()
                print("Started listening")
            } catch  {
                print("Unexpected error: \(error)")
            }
        } else {
            stopListening()
        }
    }
    
    // Listening to LIVE audio
    func startListening() throws {
        
        isListening = true
        togglePulse(pulse: true)
        
        // Setup Audio Session
        let node = audioEngine.inputNode
        
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request.append(buffer) // Using SFSpeechAudioBufferRecognitionRequest()
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        // This is the workhorse doing ALL the work while the listening session is active and after if completes (ended manually or timesout)
        // Every word that is recognized by the Speech API will be passed in here.
        recognitionTask = speechRecognizer.recognitionTask(with: request, resultHandler: { result, error in
            if let result = result
            {
                print(result.bestTranscription.formattedString)
                
                // Display the live text being transcribed
                DispatchQueue.main.async() {
                    self.transcribedTextView.text = result.bestTranscription.formattedString
                }
                
                if result.isFinal {
                    let finalString = result.bestTranscription.formattedString
                    print("Here's the final recognized text:\n\(result.bestTranscription.formattedString)")
                    
                    // This handles stopping the session automatically if the OS stops listening after about 1 minute and the users has not manually stopped the listening session by tapping the microphone
                    if(self.isListening){
                        self.stopListening()
                    }
                    
                    // Display the final transcribed text for this session
                    DispatchQueue.main.async() {
                        self.transcribedTextView.text = result.bestTranscription.formattedString
                    }
                
                    // Send final transcribed text to Amazon Translate
                    self.translateText(spokenText: finalString, targetLanguage: self.destinationLanguage)
                }
            }
        })
    }
    
    // Stop listening for audio
    func stopListening() {
        togglePulse(pulse: false)
        isListening = false
        audioEngine.stop()
        request.endAudio()
        //recognitionTask?.cancel()
        audioEngine.inputNode.removeTap(onBus: 0) // Required to record more than one session
        print("Stopped listening")
    }
    
    // Using the Pulsator framework to show we are listening.
    func togglePulse(pulse: Bool)
    {
        if(pulse) {
            self.pulsator.start()
            self.translatedTextView.text = "..."
        }
        else
        {
            DispatchQueue.main.async() {
                self.pulsator.stop()
            }
        }
    }

    // The audio/video player used to playback Polly audio stream
    func playAudio(audioURL: URL) {
        let player = AVPlayer(url: audioURL)
        player.allowsExternalPlayback = true
        let vc = AVPlayerViewController()
        vc.player = player
        
        vc.player?.play()
    }
    
    // This function calls Amazon Translate by passing in the spokenText and the target language to translate
    func translateText (spokenText: String, targetLanguage: String)   {
        
        spinner.startAnimating()
        
        // Get the language code for destination language (e.g. from "Spanish" to "es")
        let destlanguageCode = getLanguageCode(selectedlanguage: targetLanguage)

        // Uses the service configuration singleton - see serviceConfiguration in Appdelegate
        let translateClient = AWSTranslate.default()
        
        // Create Translate Request
        let translateRequest = AWSTranslateTranslateTextRequest ()
        translateRequest?.sourceLanguageCode = langCode // Language code based on Locale.current.languageCode
        translateRequest?.targetLanguageCode = destlanguageCode
        translateRequest?.text = spokenText

        translateClient.translateText(translateRequest!) { (response, error) in
            guard let response = response else {
                DispatchQueue.main.async {
                    self.translatedTextView.text = error?.localizedDescription
                }
                self.spinner.stopAnimating()
                return
            }
            if let translatedText = response.translatedText {
                DispatchQueue.main.async {
                    self.spinner.stopAnimating()
                    print(response.translatedText ?? "No translated text")
                    self.translatedTextView.text = translatedText
                }
                self.speakPolly(translatedText: translatedText, targetLanguage: targetLanguage)
            }
        }
    }
    
    // This function takes the translated text and sends to Polly
    // Polly then returns with an audio stream of the translated text and choose the appropriate voice for that language.
    func speakPolly(translatedText: String, targetLanguage: String)  {
        
        // Get the language code e.g. "fr" for French so Polly knows what voice to use
        let languageCode = getLanguageCode(selectedlanguage: targetLanguage)
        
        print("Sending translated text [\(translatedText)] from \(String(describing: langCode)) to Target Language: \(targetLanguage)(\(languageCode))")
        
        let input = AWSPollySynthesizeSpeechURLBuilderRequest()
        
        // Text to synthesize
        input.text = translatedText
        
        // Set the output format to MP3 for later streaming
        input.outputFormat = AWSPollyOutputFormat.mp3
        
        // Choose the polly voice personality based on the targetLanguage
        switch languageCode {
            case "nl":
                input.voiceId = AWSPollyVoiceId.lotte
            case "fr":
                input.voiceId = AWSPollyVoiceId.chantal
            case "de":
                input.voiceId = AWSPollyVoiceId.hans
            case "it":
                input.voiceId = AWSPollyVoiceId.carla
            case "ja":
                input.voiceId = AWSPollyVoiceId.mizuki
            case "pl":
                input.voiceId = AWSPollyVoiceId.maja
            case "pt":
                input.voiceId = AWSPollyVoiceId.ines
            case "es":
                input.voiceId = AWSPollyVoiceId.penelope
        default:
            input.voiceId = AWSPollyVoiceId.kendra // default to English en-US voice if no target language, or "en" found
        }
        
        // Create a task to synthesize speech using the given synthesis signedURL as input
        let builder = AWSPollySynthesizeSpeechURLBuilder.default().getPreSignedURL(input)
        
        // Request the URL for synthesis result. The result of getPresignedURL task is an NSURL
        builder.continueWith(block: { (AWSTask: AWSTask<NSURL>) -> Any? in
            
            guard let url = AWSTask.result else {
                return nil
            }
            
            // Using the system AVAudioPlayer (no speakers, hard to hear) vs External player
            self.audioPlayer.replaceCurrentItem(with: AVPlayerItem(url: url as URL))
            self.audioPlayer.play()
            
            //self.playAudio(audioURL: url as URL) // External player was working prior to iOS 12
            
            return nil
        })
    }
    
    // Represents the 8 languages that are supported by BOTH Polly and Translate
    // Amazon Translate supports more languages and some of those languages have a Polly voice
    func getLanguageCode(selectedlanguage: String) -> String {
        switch selectedlanguage {
            case "Dutch":
                return "nl"
            case "French":
                return "fr"
            case "German":
                return "de"
            case "Italian":
                return "it"
            case "Japanese":
                return "ja"
            case "Polish":
                return "pl"
            case "Portuguese":
                return "pt"
            case "Spanish":
                return "es"
            default:
                return "en"
        }
    }
    
    func askSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.status = .ready
                default:
                    self.status = .unavailable
                }
            }
        }
    }
    
    // Initialize the Pulsator under the live listener recordView ImageView to show we are listening visually
    func setPulsator() {
        pulsator.position = CGPoint(x: recordView.center.x, y: recordView.center.y - 30)
        pulsator.numPulse = 6
        pulsator.radius = 40
        pulsator.animationDuration = 1 // bigger number is faster
        pulsator.backgroundColor = UIColor.red.cgColor
        recordView.layer.superlayer?.insertSublayer(pulsator, below: recordView.layer)
    }
    
    enum Oops: Error {
        case FoundNil(String)
    }
    
    enum SpeechStatus {
        case ready
        case recognizing
        case unavailable
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

