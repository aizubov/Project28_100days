//
//  ViewController.swift
//  Project28_100days
//
//  Created by user228564 on 4/20/23.
//

import UIKit
import LocalAuthentication

class ViewController: UIViewController {
    
    var doneButton: UIBarButtonItem!
    let passwordKey = "password"
    var passwordButton: UIBarButtonItem!
    
    
    @IBOutlet weak var secret: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Nothing to see here"
        

        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(saveSecretMessage), name: UIApplication.willResignActiveNotification, object: nil)
        
        //
        doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(saveSecretMessage))
        navigationItem.rightBarButtonItem = doneButton
        doneButton.isEnabled = false
        
        passwordButton = UIBarButtonItem(title: "Password", style: .plain, target: self, action: #selector(setPassword))
        navigationItem.leftBarButtonItem = passwordButton
        passwordButton.isEnabled = false
    }

    @IBAction func authenticateTapped(_ sender: Any) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Identify yourself"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] (success, authenticationError) in
                DispatchQueue.main.async {
                    if success {
                        self?.unlockSecretMessage()
                    }
                    else {
                        self?.failedBiometricAuthentication(context: context)
                    }
                }
            }
        }
        else {
            useFallbackAuthentication()
        }
    }
    func failedBiometricAuthentication(context: LAContext) {
        if !hasPassword() {
            // don't want a wrong fingerprint or face to trigger password creation
            var biometryType: String
            switch context.biometryType {
            case .faceID:
                biometryType = "Face ID"
            case .touchID:
                biometryType = "Touch ID"
            case .none:
                return;
            @unknown default:
                biometryType = "Biometry"
            }
            showErrorMessage(title: "Authentication failed", message: "To use password authentication, first authenticate using \(biometryType) then set a password, or disable \(biometryType)")
        }
        else {
            useFallbackAuthentication()
        }
    }
    
    func useFallbackAuthentication() {
        if hasPassword() {
            authenticateWithPassword()
        }
        else {
            setPassword()
        }
    }
    
    func hasPassword() -> Bool {
        return KeychainWrapper.standard.hasValue(forKey: passwordKey)
    }
    
    func authenticateWithPassword() {
        let ac = UIAlertController(title: "Password authentication", message: nil, preferredStyle: .alert)
        
        ac.addTextField { textField in
            textField.isSecureTextEntry = true
            textField.placeholder = "Password"
        }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak ac] action in
            guard let password = ac?.textFields?[0].text else { return }
            
            if let passwordKey = self?.passwordKey {
                if let storedPassword = KeychainWrapper.standard.string(forKey: passwordKey) {
                    if password == storedPassword {
                        self?.unlockSecretMessage()
                        return
                    }
                }
            }
            
            self?.showErrorMessage(title: "Authentication failed", message: "You could not be verified; please try again.")
        })
        
        present(ac, animated: true)
    }
    
    func showErrorMessage(title: String, message: String? = nil) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(ac, animated: true)
    }
    
    
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

        if notification.name == UIResponder.keyboardWillHideNotification {
            secret.contentInset = .zero
        } else {
            secret.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }

        secret.scrollIndicatorInsets = secret.contentInset

        let selectedRange = secret.selectedRange
        secret.scrollRangeToVisible(selectedRange)
    }
    
    func unlockSecretMessage() {
        doneButton.isEnabled = true
        passwordButton.isEnabled = true
        secret.isHidden = false
        title = "Secret stuff!"

        if let text = KeychainWrapper.standard.string(forKey: "SecretMessage") {
            secret.text = text
        }
    }
    
    @objc func saveSecretMessage() {
        guard secret.isHidden == false else { return }

        KeychainWrapper.standard.set(secret.text, forKey: "SecretMessage")
        secret.resignFirstResponder()
        secret.isHidden = true
        title = "Nothing to see here"
        doneButton.isEnabled = false
        passwordButton.isEnabled = false
    }
    
    @objc func setPassword() {
        let ac = UIAlertController(title: "Set password", message: "It will be used as an alternative to the FaceID", preferredStyle: .alert)
        
        ac.addTextField { textField in
            textField.isSecureTextEntry = true
            textField.placeholder = "Password"
        }
        
        ac.addTextField { textField in
            textField.isSecureTextEntry = true
            textField.placeholder = "Confirm password"
        }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak ac] action in
            guard let password = self?.checkSetPasswordFields(ac: ac) else { return }
            
            if let passwordKey = self?.passwordKey {
                KeychainWrapper.standard.set(password, forKey: passwordKey)
            }
        })
        
        present(ac, animated: true)
    }
    
    func checkSetPasswordFields(ac: UIAlertController?) -> String? {
        
        guard ac?.textFields?[0].text == ac?.textFields?[1].text && ac?.textFields?[0].text != nil && ac?.textFields?[1].text != nil else {
            
            
            let ac = UIAlertController(title: "Empty text field or not matching passwords", message: nil, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            ac.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] action in
                self?.setPassword()
            })
            
            present(ac, animated: true)
            
            return nil
        }
        
        guard let password = ac?.textFields?[0].text else {
            return nil
        }
        
        return password
    }
    
}

