//
//  CubeView.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import SwiftUI
import SceneKit
import simd

struct CubeView: View {
    let title: String
    let attitude: AttitudeData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let attitude = attitude {
                SceneKitCubeView(quaternion: attitude.quaternion)
                    .background(Color.black)
                    .cornerRadius(8)
            } else {
                Text("无姿态数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - SceneKit 3D立方体视图
struct SceneKitCubeView: UIViewRepresentable {
    let quaternion: simd_quatd
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = createScene()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.black
        
        // 设置相机
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 8)
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 更新立方体的旋转
        if let cubeNode = uiView.scene?.rootNode.childNode(withName: "cube", recursively: true) {
            // 将四元数转换为SceneKit的四元数格式
            let scnQuaternion = SCNQuaternion(
                quaternion.imag.x,
                quaternion.imag.y,
                quaternion.imag.z,
                quaternion.real
            )
            cubeNode.orientation = scnQuaternion
        }
    }
    
    private func createScene() -> SCNScene {
        let scene = SCNScene()
        
        // 创建立方体
        let cube = SCNBox(width: 3.0, height: 2.0, length: 4.0, chamferRadius: 0.1)
        let cubeNode = SCNNode(geometry: cube)
        cubeNode.name = "cube"
        
        // 创建立方体的材质，每个面不同颜色
        let materials = createCubeMaterials()
        cube.materials = materials
        
        scene.rootNode.addChildNode(cubeNode)
        
        // 添加坐标轴
        addCoordinateAxes(to: scene.rootNode)
        
        return scene
    }
    
    private func createCubeMaterials() -> [SCNMaterial] {
        let colors: [UIColor] = [
            .red,       // +X (右)
            .green,     // -X (左)
            .blue,      // +Y (上)
            .yellow,    // -Y (下)
            .purple,    // +Z (前)
            .orange     // -Z (后)
        ]
        
        return colors.map { color in
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.locksAmbientWithDiffuse = true
            return material
        }
    }
    
    private func addCoordinateAxes(to parent: SCNNode) {
        // X轴 (红色)
        let xAxis = createAxisLine(length: 6, color: .red)
        xAxis.orientation = SCNQuaternion(0, 0, 0, 1) // 默认方向就是X轴
        parent.addChildNode(xAxis)
        
        // Y轴 (绿色)
        let yAxis = createAxisLine(length: 6, color: .green)
        yAxis.orientation = SCNQuaternion(0, 0, sin(Double.pi/4), cos(Double.pi/4)) // 绕Z轴旋转90度
        parent.addChildNode(yAxis)
        
        // Z轴 (蓝色)
        let zAxis = createAxisLine(length: 6, color: .blue)
        zAxis.orientation = SCNQuaternion(0, sin(-Double.pi/4), 0, cos(-Double.pi/4)) // 绕Y轴旋转-90度
        parent.addChildNode(zAxis)
    }
    
    private func createAxisLine(length: Float, color: UIColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.05, height: CGFloat(length))
        let material = SCNMaterial()
        material.diffuse.contents = color
        cylinder.materials = [material]
        
        let node = SCNNode(geometry: cylinder)
        return node
    }
}

#Preview {
    let axis = simd_double3(1, 1, 0)
    let normalizedAxis = simd_normalize(axis)
    let sampleQuaternion = simd_quatd(angle: Double.pi/4, axis: normalizedAxis)
    let sampleAttitude = AttitudeData(
        timestamp: 0,
        quaternion: sampleQuaternion,
        euler: simd_double3(45, 30, 60)
    )
    
    return CubeView(
        title: "测试3D立方体",
        attitude: sampleAttitude
    )
    .frame(height: 200)
    .padding()
}