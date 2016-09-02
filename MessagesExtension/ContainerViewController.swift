//
//  ContainerViewController.swift
//  Pinnable
//
//  Created by Jeremy Kelleher on 8/29/16.
//  Copyright © 2016 JKProductions. All rights reserved.
//

import UIKit

class ContainerViewController: ISHPullUpViewController {
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        commonInit()
    }
    
    private func commonInit() {
        let storyBoard = UIStoryboard(name: "MainInterface", bundle: nil)
        let contentVC = storyBoard.instantiateViewController(withIdentifier: "MapPinningViewController") as! MessagesViewController
        let bottomVC = storyBoard.instantiateViewController(withIdentifier: "LocationSearchTable") as! LocationSearchTable
        contentViewController = contentVC
        bottomViewController = bottomVC
        bottomVC.pullUpController = self
        contentDelegate = contentVC
        sizingDelegate = bottomVC
        stateDelegate = bottomVC
    }
}


