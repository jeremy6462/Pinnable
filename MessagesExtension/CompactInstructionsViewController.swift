//
//  CompactInstructionsViewController.swift
//  Pinnable
//
//  Created by Jeremy Kelleher on 9/8/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import UIKit

class CompactInstructionsViewController : UIViewController {
    
    @IBOutlet weak var instructions: UILabel!
    
    override func viewDidLoad() {
        instructions.layer.borderColor = UIColor.gray.cgColor
        instructions.layer.borderWidth = 2
        instructions.layer.cornerRadius = 5
        instructions.backgroundColor = UIColor.white
        instructions.text = "Tap the up arrow in the \n bottom right to start"
        
        
    }
    
}
