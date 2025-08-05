//
//  AppleMotionView.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import SwiftUI
import simd

struct AppleMotionView: View {
    @ObservedObject var viewModel: MotionDataViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 标题和数据源选择
                VStack(spacing: 8) {
                    Text("苹果姿态解算")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    // 数据源选择器
                    VStack(alignment: .leading, spacing: 4) {
                        Text("姿态数据源：")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("姿态数据源", selection: $viewModel.selectedSource) {
                            ForEach(AttitudeSource.allCases, id: \.self) { source in
                                Text(source.description).tag(source)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .disabled(viewModel.isCollecting)
                    }
                }
                .padding(.bottom, 8)
                
                // 实时数据显示
                RealTimeDataView(
                    title: "苹果姿态数据",
                    attitude: viewModel.appleAttitude,
                    displayFormat: viewModel.displayFormat
                )
                
                // 曲线图
                ChartView(
                    title: "姿态曲线 (10秒)",
                    data: viewModel.appleAttitudeHistory,
                    displayFormat: viewModel.displayFormat
                )
                .frame(height: 200)
                
                // 3D立方体
                CubeView(
                    title: "3D姿态",
                    attitude: viewModel.appleAttitude
                )
                .frame(height: 250)
            }
            .padding()
        }
    }
}

// MARK: - 控制区域
struct HeaderSection: View {
    @ObservedObject var viewModel: MotionDataViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("苹果姿态解算")
                .font(.title2)
                .fontWeight(.bold)
            
            // 数据源选择器
            VStack(alignment: .leading, spacing: 4) {
                Text("姿态数据源：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("姿态数据源", selection: $viewModel.selectedSource) {
                    ForEach(AttitudeSource.allCases, id: \.self) { source in
                        Text(source.description).tag(source)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(viewModel.isCollecting)
            }
            
            // 显示格式选择器
            VStack(alignment: .leading, spacing: 4) {
                Text("显示格式：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("显示格式", selection: $viewModel.displayFormat) {
                    ForEach(DisplayFormat.allCases, id: \.self) { format in
                        Text(format.description).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 开始/停止按钮
            Button(action: {
                if viewModel.isCollecting {
                    viewModel.stopCollection()
                } else {
                    viewModel.startCollection()
                }
            }) {
                Text(viewModel.isCollecting ? "停止采集" : "开始采集")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(viewModel.isCollecting ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - 实时数据显示
struct RealTimeDataView: View {
    let title: String
    let attitude: AttitudeData?
    let displayFormat: DisplayFormat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let attitude = attitude {
                VStack(spacing: 4) {
                    switch displayFormat {
                    case .quaternion:
                        QuaternionDisplay(quaternion: attitude.quaternion)
                    case .euler:
                        EulerDisplay(euler: attitude.euler)
                    }
                }
            } else {
                Text("无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 四元数显示
struct QuaternionDisplay: View {
    let quaternion: simd_quatd
    
    var body: some View {
        VStack(spacing: 2) {
            DataRow(label: "W", value: quaternion.real, format: "%.3f")
            DataRow(label: "X", value: quaternion.imag.x, format: "%.3f")
            DataRow(label: "Y", value: quaternion.imag.y, format: "%.3f")
            DataRow(label: "Z", value: quaternion.imag.z, format: "%.3f")
        }
    }
}

// MARK: - 欧拉角显示
struct EulerDisplay: View {
    let euler: simd_double3
    
    var body: some View {
        VStack(spacing: 2) {
            DataRow(label: "Roll", value: euler.x, format: "%.2f°")
            DataRow(label: "Pitch", value: euler.y, format: "%.2f°")
            DataRow(label: "Yaw", value: euler.z, format: "%.2f°")
        }
    }
}

// MARK: - 数据行显示
struct DataRow: View {
    let label: String
    let value: Double
    let format: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 45, alignment: .leading)
            
            Text(String(format: format, value))
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    AppleMotionView(viewModel: MotionDataViewModel())
}