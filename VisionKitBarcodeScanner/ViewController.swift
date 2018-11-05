//
//  ViewController.swift
//  VisionKitBarcodeScanner
//
//  Created by Alin Baciu on 05/11/2018.
//  Copyright © 2018 Alin Baciu. All rights reserved.
//

import UIKit

class ViewController: UIViewController, BarcodeScannerDelegate {
    

    @IBOutlet weak var resultLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @IBAction func scanPressed(_ sender: Any) {
        let navController = UINavigationController(rootViewController: BarcodeScannerViewController(delegate: self))
        self.present(navController, animated: true, completion: nil)
    }
    
    func barcodeScanner(_ scanner: BarcodeScannerViewController, read code: String) {
        DispatchQueue.main.async {
            self.resultLabel.text = code
        }
        scanner.dismiss(animated: true, completion: nil)
    }
    
    func barcodeScannerCancelled(_ scanner: BarcodeScannerViewController) {
        scanner.dismiss(animated: true, completion: nil)
    }
    
    func barcodeScannerFailed(_ scanner: BarcodeScannerViewController) {
        scanner.dismiss(animated: true, completion: nil)
    }
}

