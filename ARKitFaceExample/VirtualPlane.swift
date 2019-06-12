//
//  VirtualPlane.swift
//  FreeRealEstate
//
//  Created by Cole Margerum on 12/1/18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import Foundation
import ARKit
import SceneKit

class VirtualPlane: SCNNode {
    var anchor: ARPlaneAnchor!
    var plane: SCNPlane!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(anchor: ARPlaneAnchor) {
        super.init()
        
        self.anchor = anchor
        plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let material = initializePlaneMaterial()
        plane.materials = [material]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        
        updatePlaneMaterialDimensions()
        self.addChildNode(planeNode)
    }
    
    func initializePlaneMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        let lightBlue = UIColor(displayP3Red: 0.53, green: 0.81, blue: 0.98, alpha: 0.3)
        material.diffuse.contents = lightBlue
        return material
    }
    
    func updatePlaneMaterialDimensions() {
        let material = plane.materials.first!
        let width = Float(plane.width)
        let height = Float(plane.height)
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(width, height, 1.0)
    }
    
    func updateWithNewAnchor(_ anchor: ARPlaneAnchor) {
        plane.width = CGFloat(anchor.extent.x)
        plane.height = CGFloat(anchor.extent.z)
        position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        updatePlaneMaterialDimensions()
    }
}
