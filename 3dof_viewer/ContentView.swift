//
//  ContentView.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var motionViewModel = MotionDataViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部控制区域
            VStack(spacing: 12) {
                Text("3DOF 姿态查看器")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 控制按钮和显示格式选择
                HStack(spacing: 20) {
                    // 开始/停止按钮
                    Button(action: {
                        if motionViewModel.isCollecting {
                            motionViewModel.stopCollection()
                        } else {
                            motionViewModel.startCollection()
                        }
                    }) {
                        Text(motionViewModel.isCollecting ? "停止采集" : "开始采集")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(motionViewModel.isCollecting ? Color.red : Color.green)
                            .cornerRadius(22)
                    }
                    
                    // 显示格式选择
                    Picker("显示格式", selection: $motionViewModel.displayFormat) {
                        ForEach(DisplayFormat.allCases, id: \.self) { format in
                            Text(format.description).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }
                
                // 采样率显示
                HStack(spacing: 30) {
                    Text("苹果采样率: \(String(format: "%.1f", motionViewModel.appleSampleRate)) Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("VQF采样率: \(String(format: "%.1f", motionViewModel.vqfSampleRate)) Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // 主要内容区域
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 左侧：苹果姿态数据
                    AppleMotionView(viewModel: motionViewModel)
                        .frame(width: geometry.size.width / 2)
                        .background(Color.gray.opacity(0.1))
                    
                    // 分割线
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 1)
                    
                    // 右侧：VQF姿态数据
                    VQFMotionView(viewModel: motionViewModel)
                        .frame(width: geometry.size.width / 2)
                        .background(Color.blue.opacity(0.1))
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ContentView()
    }
}
