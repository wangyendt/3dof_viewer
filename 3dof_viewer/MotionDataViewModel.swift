//
//  MotionDataViewModel.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import Foundation
import CoreMotion
import Combine
import simd

// 姿态数据源类型
enum AttitudeSource: String, CaseIterable {
    case deviceMotion6D = "设备运动 (6轴)"
    case deviceMotion9D = "设备运动 (9轴)"
    case gameRotation = "游戏旋转 (6轴)"
    case attitude = "设备姿态 (9轴)"
    
    var description: String {
        return self.rawValue
    }
}

// 显示格式
enum DisplayFormat: String, CaseIterable {
    case quaternion = "四元数 (wxyz)"
    case euler = "欧拉角 (zyx度)"
    
    var description: String {
        return self.rawValue
    }
}

// 姿态数据结构
struct AttitudeData {
    let timestamp: TimeInterval
    let quaternion: simd_quatd    // w,x,y,z
    let euler: simd_double3       // roll, pitch, yaw (度)
}

// 传感器原始数据
struct SensorData {
    let timestamp: TimeInterval
    let accelerometer: simd_double3
    let gyroscope: simd_double3
    let magnetometer: simd_double3?
}

class MotionDataViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isCollecting = false
    @Published var selectedSource: AttitudeSource = .deviceMotion9D
    @Published var displayFormat: DisplayFormat = .euler
    
    // 苹果姿态数据
    @Published var appleAttitude: AttitudeData?
    @Published var appleAttitudeHistory: [AttitudeData] = []
    
    // VQF姿态数据
    @Published var vqfAttitude: AttitudeData?
    @Published var vqfAttitudeHistory: [AttitudeData] = []
    
    // 原始传感器数据
    @Published var currentSensorData: SensorData?
    
    // 采样率计算
    @Published var appleSampleRate: Double = 0.0
    @Published var vqfSampleRate: Double = 0.0
    
    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    // TODO: 需要配置桥接头文件后启用
    private var vqfBridge: VQFBridge?
    private let sampleTime: Double = 0.01 // 100Hz
    private var vqfTimer: DispatchSourceTimer?
    private var uiUpdateTimer: Timer?
    
    // 专用队列
    private let vqfQueue = DispatchQueue(label: "vqf.processing.queue", qos: .userInitiated)
    private let sensorQueue = OperationQueue()
    
    init() {
        setupMotionManager()
        initializeVQF()
        setupQueues()
    }
    
    private func setupQueues() {
        sensorQueue.qualityOfService = .userInitiated
        sensorQueue.name = "sensor.processing.queue"
        sensorQueue.maxConcurrentOperationCount = 1 // 串行队列
    }
    
    // 数据历史窗口（10秒）
    private let maxHistoryDuration: TimeInterval = 10.0
    private var startTime: TimeInterval?
    
    // UI更新频率控制
    private let uiUpdateInterval: Double = 1.0 / 30.0 // 30Hz UI更新
    
    // 采样率计算
    private var lastAppleUpdateTime: TimeInterval = 0
    private var lastVqfUpdateTime: TimeInterval = 0
    private var appleSampleTimes: [TimeInterval] = []
    private var vqfSampleTimes: [TimeInterval] = []
    private let sampleRateWindowSize = 50  // 计算最近50个样本的平均采样率
    private var sampleRateUpdateCounter = 0  // 计数器，每10次更新一次采样率显示
    
    // 数据缓存（用于UI更新）
    private var latestAppleAttitude: AttitudeData?
    private var latestVqfAttitude: AttitudeData?
    private var latestSensorData: SensorData?
    private var latestAppleSampleRate: Double = 0.0
    private var latestVqfSampleRate: Double = 0.0
    
    // MARK: - Setup
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 1.0 / 200.0  // 设置200Hz实际达到100Hz
        motionManager.gyroUpdateInterval = 1.0 / 200.0
        motionManager.magnetometerUpdateInterval = 1.0 / 200.0
        motionManager.deviceMotionUpdateInterval = 1.0 / 200.0
    }
    
    private func initializeVQF() {
        // TODO: 需要配置桥接头文件后启用
         vqfBridge = VQFBridge(gyrTs: sampleTime, accTs: sampleTime)
    }
    
    // MARK: - Data Collection Control
    func startCollection() {
        guard !isCollecting else { return }
        
        isCollecting = true
        startTime = nil
        appleAttitudeHistory.removeAll()
        vqfAttitudeHistory.removeAll()
        
        // 重新初始化VQF
        initializeVQF()
        
        startMotionUpdates()
    }
    
    func stopCollection() {
        guard isCollecting else { return }
        
        isCollecting = false
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopMagnetometerUpdates()
        
        // 停止所有定时器
        vqfTimer?.cancel()
        vqfTimer = nil
        uiUpdateTimer?.invalidate()
        uiUpdateTimer = nil
    }
    
    // MARK: - Motion Updates
    private func startMotionUpdates() {
        // 根据选择的数据源启动不同的更新
        switch selectedSource {
        case .deviceMotion6D:
            startDeviceMotionUpdates(useReferenceFrame: false)
        case .deviceMotion9D:
            startDeviceMotionUpdates(useReferenceFrame: true)
        case .gameRotation:
            startGameRotationUpdates()
        case .attitude:
            startAttitudeUpdates()
        }
        
        // 启动原始传感器数据更新（用于VQF）
        startRawSensorUpdates()
        
        // 启动UI更新定时器
        startUIUpdateTimer()
    }
    
    private func startDeviceMotionUpdates(useReferenceFrame: Bool) {
        let referenceFrame: CMAttitudeReferenceFrame = useReferenceFrame ? 
            .xMagneticNorthZVertical : .xArbitraryZVertical
        
        motionManager.startDeviceMotionUpdates(using: referenceFrame, to: sensorQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion, self.isCollecting else { return }
            
            self.processAppleMotionData(motion: motion)
        }
    }
    
    private func startGameRotationUpdates() {
        // iOS的游戏旋转向量实际上通过CMDeviceMotion获取，设置为不使用磁力计
        startDeviceMotionUpdates(useReferenceFrame: false)
    }
    
    private func startAttitudeUpdates() {
        // 使用设备姿态（包含磁力计校正）
        startDeviceMotionUpdates(useReferenceFrame: true)
    }
    
    private func startRawSensorUpdates() {
        // 启动加速度计
        motionManager.startAccelerometerUpdates()
        // 启动陀螺仪
        motionManager.startGyroUpdates()
        // 启动磁力计
        motionManager.startMagnetometerUpdates()
        
        // 使用高性能DispatchSourceTimer在后台队列中处理VQF (100Hz)
        vqfTimer = DispatchSource.makeTimerSource(queue: vqfQueue)
        vqfTimer?.schedule(deadline: .now(), repeating: sampleTime)
        vqfTimer?.setEventHandler { [weak self] in
            self?.processRawSensorData()
        }
        vqfTimer?.resume()
    }
    
    private func startUIUpdateTimer() {
        // 使用独立的定时器更新UI (30Hz)
        uiUpdateTimer = Timer.scheduledTimer(withTimeInterval: uiUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateUI()
        }
    }
    
    // MARK: - Data Processing
    private func processAppleMotionData(motion: CMDeviceMotion) {
        let timestamp = motion.timestamp
        if startTime == nil {
            startTime = timestamp
        }
        
        // 获取四元数（注意CoreMotion的四元数是标量在前：w,x,y,z）
        let quat = motion.attitude.quaternion
        let quaternion = simd_quatd(ix: quat.x, iy: quat.y, iz: quat.z, r: quat.w)
        
        // 转换为欧拉角
        let euler = quaternionToEuler(quaternion)
        
        let attitudeData = AttitudeData(
            timestamp: timestamp,
            quaternion: quaternion,
            euler: euler
        )
        
        // 缓存数据，不立即更新UI
        latestAppleAttitude = attitudeData
        
        // 更新采样率计算（这个可以在后台线程进行）
        updateAppleSampleRate(timestamp: timestamp)
    }
    
    private func processRawSensorData() {
        guard let accData = motionManager.accelerometerData,
              let gyroData = motionManager.gyroData else { return }
        
        let timestamp = Date().timeIntervalSinceReferenceDate
        if startTime == nil {
            startTime = timestamp
        }
        
        // 获取原始传感器数据
        let acc = simd_double3(accData.acceleration.x * 9.81,
                              accData.acceleration.y * 9.81,
                              accData.acceleration.z * 9.81)
        let gyro = simd_double3(gyroData.rotationRate.x,
                               gyroData.rotationRate.y,
                               gyroData.rotationRate.z)
        
        var mag: simd_double3? = nil
        if let magData = motionManager.magnetometerData {
            mag = simd_double3(magData.magneticField.x,
                              magData.magneticField.y,
                              magData.magneticField.z)
        }
        
        let sensorData = SensorData(
            timestamp: timestamp,
            accelerometer: acc,
            gyroscope: gyro,
            magnetometer: mag
        )
        
        // 缓存传感器数据，不立即更新UI
        latestSensorData = sensorData
        
        // 更新VQF
        updateVQF(with: sensorData)
    }
    
    private func updateVQF(with sensorData: SensorData) {
        guard let vqf = vqfBridge else { return }
        
        // 转换数据格式为VQF需要的格式
        let accArray = [sensorData.accelerometer.x, sensorData.accelerometer.y, sensorData.accelerometer.z]
        let gyroArray = [sensorData.gyroscope.x, sensorData.gyroscope.y, sensorData.gyroscope.z]
        
        // 更新VQF算法
        accArray.withUnsafeBufferPointer { accPtr in
            gyroArray.withUnsafeBufferPointer { gyroPtr in
                vqf.updateGyr(sampleTime, gyr: UnsafeMutablePointer<Double>(mutating: gyroPtr.baseAddress!))
                vqf.updateAcc(sampleTime, acc: UnsafeMutablePointer<Double>(mutating: accPtr.baseAddress!))
            }
        }
        
        // 获取VQF计算的四元数 (wxyz格式)
        var quaternionArray = [Double](repeating: 0, count: 4)
        quaternionArray.withUnsafeMutableBufferPointer { quatPtr in
            vqf.getQuat6D(quatPtr.baseAddress!)
        }
        
        // VQF返回的是wxyz格式，创建simd_quatd
        let quaternion = simd_quatd(ix: quaternionArray[1], iy: quaternionArray[2], 
                                   iz: quaternionArray[3], r: quaternionArray[0])
        let euler = quaternionToEuler(quaternion)
        
        let attitudeData = AttitudeData(
            timestamp: sensorData.timestamp,
            quaternion: quaternion,
            euler: euler
        )
        
        // 缓存VQF数据，不立即更新UI
        latestVqfAttitude = attitudeData
        
        // 更新采样率计算（这个可以在后台线程进行）
        updateVqfSampleRate(timestamp: sensorData.timestamp)
    }
    
    // MARK: - UI Update
    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 更新苹果姿态数据
            if let appleData = self.latestAppleAttitude {
                self.appleAttitude = appleData
                self.addToHistory(&self.appleAttitudeHistory, data: appleData)
            }
            
            // 更新VQF姿态数据
            if let vqfData = self.latestVqfAttitude {
                self.vqfAttitude = vqfData
                self.addToHistory(&self.vqfAttitudeHistory, data: vqfData)
            }
            
            // 更新传感器数据
            if let sensorData = self.latestSensorData {
                self.currentSensorData = sensorData
            }
            
            // 更新采样率显示（批量更新，减少主线程负载）
            self.appleSampleRate = self.latestAppleSampleRate
            self.vqfSampleRate = self.latestVqfSampleRate
        }
    }
    
    // MARK: - Utility Methods
    private func addToHistory(_ history: inout [AttitudeData], data: AttitudeData) {
        history.append(data)
        
        // 保持历史数据在10秒窗口内
        let cutoffTime = data.timestamp - maxHistoryDuration
        history.removeAll { $0.timestamp < cutoffTime }
    }
    
    // 四元数转欧拉角 (ZYX外旋，单位：度)
    private func quaternionToEuler(_ q: simd_quatd) -> simd_double3 {
        let w = q.real
        let x = q.imag.x
        let y = q.imag.y
        let z = q.imag.z
        
        // ZYX欧拉角转换（外旋）
        let roll = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y))
        let pitch = asin(2 * (w * y - z * x))
        let yaw = atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
        
        // 转换为度
        return simd_double3(roll * 180 / Double.pi, pitch * 180 / Double.pi, yaw * 180 / Double.pi)
    }
    
    // MARK: - Sample Rate Calculation
    private func updateAppleSampleRate(timestamp: TimeInterval) {
        appleSampleTimes.append(timestamp)
        
        // 保持窗口大小
        if appleSampleTimes.count > sampleRateWindowSize {
            appleSampleTimes.removeFirst()
        }
        
        // 计算采样率 (如果有足够的样本)，每10次更新一次显示
        if appleSampleTimes.count >= 2 {
            let timeSpan = appleSampleTimes.last! - appleSampleTimes.first!
            latestAppleSampleRate = Double(appleSampleTimes.count - 1) / timeSpan
        }
    }
    
    private func updateVqfSampleRate(timestamp: TimeInterval) {
        vqfSampleTimes.append(timestamp)
        
        // 保持窗口大小
        if vqfSampleTimes.count > sampleRateWindowSize {
            vqfSampleTimes.removeFirst()
        }
        
        // 计算采样率 (如果有足够的样本)，缓存结果
        if vqfSampleTimes.count >= 2 {
            let timeSpan = vqfSampleTimes.last! - vqfSampleTimes.first!
            latestVqfSampleRate = Double(vqfSampleTimes.count - 1) / timeSpan
        }
    }
    
    deinit {
        stopCollection()
    }
}
