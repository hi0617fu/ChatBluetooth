import UIKit
import Firebase
import FirebaseUI
import FirebaseAuth
import GoogleSignIn

class CentralSigninViewController: UIViewController, FUIAuthDelegate {
    
    @IBOutlet weak var authButtonP: UIButton!
    @IBOutlet weak var authButtonC: UIButton!
    
    enum buttonType {
        case Peripheral
        case Central
    }
    var type: buttonType!
    var PauthUI: FUIAuth { get { return FUIAuth.defaultAuthUI()!}}
    var CauthUI: FUIAuth { get { return FUIAuth.defaultAuthUI()!}}
    let providers: [FUIAuthProvider] = [
        FUIGoogleAuth(),
        FUIFacebookAuth(),
        FUIEmailAuth()
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.PauthUI.delegate = self
        self.PauthUI.providers = providers
        self.CauthUI.delegate = self
        self.CauthUI.providers = providers
        authButtonP.addTarget(self,action: #selector(self.authButtonPTapped(sender:)),for: .touchUpInside)
        authButtonC.addTarget(self,action: #selector(self.authButtonCTapped(sender:)),for: .touchUpInside)

    }
    @objc func authButtonPTapped(sender : AnyObject) {
        self.type = .Peripheral
        // FirebaseUIのViewの取得
        let authViewController = self.PauthUI.authViewController()
        // FirebaseUIのViewの表示
        self.present(authViewController, animated: true, completion: nil)
    }
    @objc func authButtonCTapped(sender : AnyObject) {
        // FirebaseUIのViewの取得
        self.type = .Central
        let authViewController = self.CauthUI.authViewController()
        // FirebaseUIのViewの表示
        self.present(authViewController, animated: true, completion: nil)
    }
    public func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?){
        switch type {
        case .Peripheral:
            // pボタンが押されたときの処理
            if error == nil {
                 self.performSegue(withIdentifier: "PeripheralViewController", sender: nil)
             } else {
             //失敗した場合
                 print("error")
             }
        case .Central:
            // cボタンが押されたときの処理
            if error == nil {
                 self.performSegue(withIdentifier: "CentralViewController", sender: nil)
             } else {
             //失敗した場合
                 print("error")
             }
        case .none:
            break
        }
    }

}


