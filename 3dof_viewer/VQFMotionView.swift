//
//  VQFMotionView.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import SwiftUI
import simd

struct VQFMotionView: View {
    @ObservedObject var viewModel: MotionDataViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 标题区域
                VStack(spacing: 8) {
                    Text("VQF姿态解算")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 4) {
                        Text("数据源：6轴 (Acc + Gyro)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("算法：VQF")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 采集状态指示
                    HStack {
                        Circle()
                            .fill(viewModel.isCollecting ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text("采集中")
                            .font(.caption)
                            .foregroundColor(viewModel.isCollecting ? .green : .gray)
                    }
                }
                .padding(.bottom, 8)
                
                // 原始传感器数据显示
                SensorDataView(sensorData: viewModel.currentSensorData)
                
                // VQF计算的姿态数据
                RealTimeDataView(
                    title: "VQF 3DOF姿态",
                    attitude: viewModel.vqfAttitude,
                    displayFormat: viewModel.displayFormat
                )
                
                // 曲线图
                ChartView(
                    title: "VQF姿态曲线 (10秒)",
                    data: viewModel.vqfAttitudeHistory,
                    displayFormat: viewModel.displayFormat
                )
                .frame(height: 200)
                
                // 3D立方体
                CubeView(
                    title: "VQF 3D姿态",
                    attitude: viewModel.vqfAttitude
                )
                .frame(height: 250)
            }
            .padding()
        }
    }
}

// MARK: - VQF标题区域
struct VQFHeaderSection: View {
    @ObservedObject var viewModel: MotionDataViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("VQF姿态解算")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("数据源：6轴 (Acc + Gyro)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("算法：VQF")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 状态指示器
                HStack {
                    Circle()
                        .fill(viewModel.isCollecting ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(viewModel.isCollecting ? "采集中" : "已停止")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 原始传感器数据显示
struct SensorDataView: View {
    let sensorData: SensorData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原始传感器数据 (100Hz)")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let data = sensorData {
                HStack(spacing: 16) {
                    // 加速度计
                    VStack(alignment: .leading, spacing: 2) {
                        Text("加速度计 (m/s²)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        SensorAxisData(label: "X", value: data.accelerometer.x)
                        SensorAxisData(label: "Y", value: data.accelerometer.y)
                        SensorAxisData(label: "Z", value: data.accelerometer.z)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 陀螺仪
                    VStack(alignment: .leading, spacing: 2) {
                        Text("陀螺仪 (rad/s)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        SensorAxisData(label: "X", value: data.gyroscope.x)
                        SensorAxisData(label: "Y", value: data.gyroscope.y)
                        SensorAxisData(label: "Z", value: data.gyroscope.z)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("无传感器数据")
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

// MARK: - 传感器轴数据显示
struct SensorAxisData: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption2)
                .frame(width: 15, alignment: .leading)
            
            Text(String(format: "%7.3f", value))
                .font(.system(.caption2, design: .monospaced))
                .frame(alignment: .trailing)
        }
    }
}

#Preview {
    VQFMotionView(viewModel: MotionDataViewModel())
}