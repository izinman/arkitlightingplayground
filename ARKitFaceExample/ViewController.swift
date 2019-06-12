/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSessionDelegate {
    
    // MARK: Outlets

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var tabBar: UITabBar!
    var arrow: SCNNode?
    var count = 0
    // MARK: Properties
    var estdir: simd_float3?
    var estint: CGFloat?
    var ambient: SCNLight?
    var ambin: CGFloat?
    var ambcolor: CGFloat?
    var cubemap = false

    var contentControllers: [VirtualContentType: VirtualContentController] = [:]
    
    var selectedVirtualContent: VirtualContentType! {
        didSet {
            guard oldValue != nil, oldValue != selectedVirtualContent
                else { return }
            
            // Remove existing content when switching types.
            contentControllers[oldValue]?.contentNode?.removeFromParentNode()
            
            // If there's an anchor already (switching content), get the content controller to place initial content.
            // Otherwise, the content controller will place it in `renderer(_:didAdd:for:)`.
            if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
                let newContent = selectedContentController.renderer(sceneView, nodeFor: anchor) {
                node.addChildNode(newContent)
            }
        }
    }
    var selectedContentController: VirtualContentController {
        if let controller = contentControllers[selectedVirtualContent] {
            return controller
        } else {
            let controller = selectedVirtualContent.makeController()
            contentControllers[selectedVirtualContent] = controller
            return controller
        }
    }
    
    var currentFaceAnchor: ARFaceAnchor?
    
    // MARK: - View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isHidden = true
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        sceneView.automaticallyUpdatesLighting = false
        if (cubemap) {
            var bg: [UIImage] = []
            for image in ["0", "1", "2", "3", "4", "5"] {
                bg.append(UIImage(named: image + ".jpg")!)
            }
//            for image in ["red", "bpw", "bpw", "bpw", "bpw", "red"] {
//                bg.append(UIImage(named: image + ".jpg")!)
//            }
            sceneView.scene.lightingEnvironment.contents = bg
        }

        if #available(iOS 11.3, *) {
            let tapGesture = UITapGestureRecognizer(target: self, action:  #selector(placeObject(_:)))
            sceneView.addGestureRecognizer(tapGesture)
        }
        sceneView.debugOptions = [.showWorldOrigin]
        
        // Set the initial face content.
        tabBar.selectedItem = tabBar.items!.first!
        selectedVirtualContent = VirtualContentType(rawValue: tabBar.selectedItem!.tag)
        //sceneView.scene.lightingEnvironment.contents = UIImage(named: "cubemap.png")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // AR experiences typically involve moving the device without
        // touch input for some time, so prevent auto screen dimming.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // "Reset" to run the AR session for the first time.
        resetTracking()
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        ambin = frame.lightEstimate?.ambientIntensity
        ambcolor = frame.lightEstimate?.ambientColorTemperature
        ambient?.intensity = ambin ?? 0
        ambient?.temperature = ambcolor ?? 0
        if (count < 250)
        {
            count += 1;
        }
        if (count == 250) {
            count += 1
            startFlippedSession()
            return
//            let tmpnode = SCNReferenceNode(named: "arrow")
//            tmpnode.position = SCNVector3(0, 0, -0.5)
//            tmpnode.scale = SCNVector3(0.1, 0.1, 0.1)
//            tmpnode.eulerAngles.x = 3.1415926 / 4
//            arrow = tmpnode
//            sceneView.pointOfView?.addChildNode(tmpnode)
        }
        //if (count == 251) { return }
        guard let lightEstimate = frame.lightEstimate as? ARDirectionalLightEstimate else {
            return
        }
        var floats: [Float32] = []

        estint = lightEstimate.primaryLightIntensity
        estdir = lightEstimate.primaryLightDirection
        let lineNode = SCNNode(geometry: SCNGeometry.lineFrom(vector: SCNVector3Zero, toVector: SCNVector3(estdir!.x, estdir!.y, -estdir!.z)))
        sceneView.scene.rootNode.addChildNode(lineNode)
        //let front = sceneView.pointOfView?.simdWorldFront
        let flipped = simd_float3(estdir!.x, estdir!.y, -estdir!.z)
        estdir = flipped
        lightEstimate.sphericalHarmonicsCoefficients.withUnsafeBytes{(pointer: UnsafePointer<Float32>) in
            for i in 0...26 {
                floats.append(pointer[i])
            }
        }
        //let root = sceneView.scene.rootNode
        //print("exploring scene graph")
        //explorechildnodes(root)
    }
    
    private func startFlippedSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        sceneView.automaticallyUpdatesLighting = false
        if (!cubemap) {
            let newAmbient = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = ambin!
            ambient.temperature = ambcolor!
            ambient.categoryBitMask = 42
            newAmbient.light = ambient
            self.ambient = ambient
            sceneView.scene.rootNode.addChildNode(newAmbient)
        }
        let newNode = SCNNode()
        let newLight = SCNLight()
        newLight.type = .directional
        newLight.intensity = estint!
        newLight.categoryBitMask = 42
        newLight.temperature = ambcolor!
        newNode.light = newLight
        let dot = -estdir!.z
        let rotAngle = acos(dot)
        let rotAxis = SCNVector3(0, 0, -1).cross(vector: SCNVector3(estdir!)).normalized()
        let quat = simd_quatf(angle: rotAngle, axis: float3(rotAxis))
        newNode.simdOrientation = quat
        sceneView.scene.rootNode.addChildNode(newNode)
    }
    
    func explorechildnodes(_ pnode: SCNNode) {
        for node in pnode.childNodes {
            explorechildnodes(node)
            print(node.name ?? "")
            guard let inspectme = node.light else { return }
            print("DICK")
        }
    }
    
    
    @objc @available(iOS 11.3, *)
    func placeObject(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        // Perform a hit test to obtain the plane on which we will place the object
        let planeHits = sceneView.hitTest(location, types: .existingPlaneUsingGeometry)
        
        // Verify that the plane is valid
        if (planeHits.count == 0) {
            print("No planes hit")
            return;
        }
        if planeHits.count > 0, let hitResult = planeHits.first {
            // Create an object to place
            guard let newNode = createNode(objName: "zeus-2_1", hitResult: hitResult) else { return }
            
            sceneView.scene.rootNode.addChildNode(newNode)
        }
    }
    
    func createNode(objName: String?, hitResult: ARHitTestResult) -> SCNNode? {
        // Create a node object from the .scn file
        guard let name = objName else { return nil }
        let scnFileName = "Models.scnassets/" + name + ".scn"
        
        guard let tmpScene = SCNScene(named: scnFileName) else { return nil }
        let child_node = "zeus-2_zeus-2"
        
        let node = tmpScene.rootNode.childNode(withName: child_node, recursively: true)!
        
        // Initialize rotation value to ensure the object will be properly oriented
        let rotation = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y, 0, 1, 0))
        let hitTransform = simd_mul(hitResult.worldTransform, rotation)
        
        // Get the bounding box values to set the pivot to be at the center of the node
        var minVec = SCNVector3Zero
        var maxVec = SCNVector3Zero
        (minVec, maxVec) =  node.boundingBox
        
        // Set the nodes pivot appropriately
        node.pivot = SCNMatrix4MakeTranslation(
            minVec.x + (maxVec.x - minVec.x)/2,
            minVec.y,
            minVec.z + (maxVec.z - minVec.z)/2
        )
        
        // Scale, rotate, and place the node so it sits on the plane
        node.transform = SCNMatrix4(hitTransform)
        node.position = SCNVector3(hitResult.worldTransform.columns.3.x, hitResult.worldTransform.columns.3.y, hitResult.worldTransform.columns.3.z)
        
        node.geometry?.firstMaterial?.lightingModel = .physicallyBased
        node.geometry?.materials[1].lightingModel = .physicallyBased
        node.categoryBitMask = 42
        node.scale = SCNVector3(0.09, 0.09, 0.09)
        
        return node
    }
    
    /// - Tag: ARFaceTrackingSetup
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension ViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let contentType = VirtualContentType(rawValue: item.tag)
            else { fatalError("unexpected virtual content tag") }
        selectedVirtualContent = contentType
    }
}

extension ViewController: ARSCNViewDelegate {
        
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor
        
        // If this is the first time with this anchor, get the controller to create content.
        // Otherwise (switching content), will change content when setting `selectedVirtualContent`.
        if node.childNodes.isEmpty, let contentNode = selectedContentController.renderer(renderer, nodeFor: faceAnchor) {
            node.addChildNode(contentNode)
        }
    }
    
    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
            let contentNode = selectedContentController.contentNode,
            contentNode.parent == node
            else { return }
        
        selectedContentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }
}

extension SCNGeometry {
    class func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]
        
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)

        return SCNGeometry(sources: [source], elements: [element])
        
    }
}

extension SCNVector3 {
    func cross(vector: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(y * vector.z - z * vector.y, z * vector.x - x * vector.z, x * vector.y - y * vector.x)
    }
    func length() -> Float {
        return sqrtf(x*x + y*y + z*z)
    }
    
    static func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3Make(vector.x / scalar, vector.y / scalar, vector.z / scalar)
    }
    
    func normalized() -> SCNVector3 {
        return self / length()
    }
}
