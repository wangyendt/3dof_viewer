//
//  ChartView.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import SwiftUI
import Charts
import simd

struct ChartView: View {
    let title: String
    let data: [AttitudeData]
    let displayFormat: DisplayFormat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            if !data.isEmpty {
                VStack(spacing: 4) {
                    if displayFormat == .quaternion {
                        Text("显示欧拉角曲线")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    // 显式图例（放在曲线图上方，避免覆盖）
                    HStack(spacing: 12) {
                        LegendItem(color: .red, label: "Roll")
                        LegendItem(color: .green, label: "Pitch")
                        LegendItem(color: .blue, label: "Yaw")
                    }
                    EulerChart(data: data)
                }
            } else {
                Text("无数据")
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

// MARK: - 欧拉角曲线图
struct EulerChart: View {
    let data: [AttitudeData]
    
    // 计算相对时间（以第一个数据点为起点）
    private var chartData: [(time: Double, roll: Double, pitch: Double, yaw: Double)] {
        guard let firstTime = data.first?.timestamp else { return [] }
        
        return data.map { attitude in
            let relativeTime = attitude.timestamp - firstTime
            return (
                time: relativeTime,
                roll: attitude.euler.x,
                pitch: attitude.euler.y,
                yaw: attitude.euler.z
            )
        }
    }
    
    // 横轴范围与刻度
    private var xMax: Double { max(chartData.last?.time ?? 0, 10) }
    private var xDomain: ClosedRange<Double> { max(xMax - 10, 0)...xMax }
    
    var body: some View {
        Chart(chartData, id: \.time) { point in
            LineMark(
                x: .value("时间", point.time),
                y: .value("Roll", point.roll),
                series: .value("数据系列", "Roll")
            )
            .foregroundStyle(.red)
            .symbol(.circle)
            .symbolSize(data.count > 100 ? 0 : 3)
            
            LineMark(
                x: .value("时间", point.time),
                y: .value("Pitch", point.pitch),
                series: .value("数据系列", "Pitch")
            )
            .foregroundStyle(.green)
            .symbol(.square)
            .symbolSize(data.count > 100 ? 0 : 3)
            
            LineMark(
                x: .value("时间", point.time),
                y: .value("Yaw", point.yaw),
                series: .value("数据系列", "Yaw")
            )
            .foregroundStyle(.blue)
            .symbol(.triangle)
            .symbolSize(data.count > 100 ? 0 : 3)
        }
        // 横轴使用滚动窗口：最近10秒（早期不足10秒时从0开始）
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(position: .bottom, values: .stride(by: 2)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.3))
                AxisTick()
                AxisValueLabel() {
                    if let time = value.as(Double.self) {
                        Text(String(format: "%.1fs", time))
                            .font(.caption2)
                            .foregroundStyle(Color.black)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.3))
                AxisTick()
                AxisValueLabel() {
                    if let angle = value.as(Double.self) {
                        Text(String(format: "%.0f°", angle))
                            .font(.caption2)
                            .foregroundStyle(Color.black)
                    }
                }
            }
        }
        // 坐标轴标题（显式显示）
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            Text("Time (s)").font(.caption).foregroundStyle(Color.black)
        }
        .chartYAxisLabel(position: .leading, alignment: .center) {
            Text("Euler Angle (deg)")
                .font(.caption)
                .foregroundStyle(Color.black)
                .rotationEffect(.degrees(180))
                .fixedSize()
        }
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - 图例项
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    let sampleData: [AttitudeData] = (0..<50).map { i in
        let quaternion = simd_quatd(angle: 0, axis: simd_double3(1, 0, 0))
        let euler = simd_double3(
            sin(Double(i) * 0.1) * 30, // Roll
            cos(Double(i) * 0.1) * 20, // Pitch
            Double(i) * 2             // Yaw
        )
        return AttitudeData(
            timestamp: Double(i) * 0.1,
            quaternion: quaternion,
            euler: euler
        )
    }
    
    return ChartView(
        title: "测试曲线",
        data: sampleData,
        displayFormat: .euler
    )
    .frame(height: 200)
    .padding()
}