//
//  ContentView.swift
//  IconEditor
//
//  Created by Lilong Zhang on 2024/12/29.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var iconImage: NSImage?
    @State private var targetSize: CGFloat = 512
    @State private var isHovering = false
    @State private var customWidth: String = ""
    @State private var customHeight: String = ""
    @State private var isCustomSize = false
    @State private var autoRoundCorners = false
    
    let availableSizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
    
    var body: some View {
        HStack(alignment:.top, spacing: 30){
            // 图片显示区域
            VStack(spacing: 20) {
                if let image = iconImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 256, height: 256)
                    Button(action: selectNewImage) {
                        Label("更换图标", systemImage: "arrow.triangle.2.circlepath")
                            .frame(width: 120)
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 32)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 256, height: 256)
                            .foregroundColor(isHovering ? .blue : .gray)
                        
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.largeTitle)
                            Text("拖拽图标到这里")
                                .padding(.top, 8)
                        }
                    }
                    .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                        loadDroppedImage(providers: providers)
                        return true
                    }
                }
            }
            
            // 操作区域
            VStack(alignment:.leading, spacing: 10) {
                Text("目标尺寸:")
                Picker("", selection: $targetSize) {
                    ForEach(availableSizes, id: \.self) { size in
                        Text("\(Int(size))x\(Int(size))")
                    }
                    Text("自定义")
                        .tag(CGFloat(-1))
                }
                .pickerStyle(.radioGroup)
                .onChange(of: targetSize) { oldValue, newValue in
                    isCustomSize = (newValue == -1)
                }
                
                if isCustomSize {
                    HStack {
                        TextField("宽", text: $customWidth)
                            .frame(width: 60)
                        Text("x")
                        TextField("高", text: $customHeight)
                            .frame(width: 60)
                    }
                    .textFieldStyle(.roundedBorder)
                }
                
                Toggle(isOn: $autoRoundCorners) {
                    Text("自动圆角")
                }
                .help("将图标四角裁剪为圆角，半径为宽度的17.54%")
                
                Button(action: exportImage) {
                    Label("导出图标", systemImage: "square.and.arrow.up")
                        .frame(width: 120, alignment: .center)
                }
                .disabled(iconImage == nil)
                .buttonStyle(.borderedProminent)
            }
            .frame(width: 150, alignment: .leading)
        }
        .padding()
        .frame(width: 800, height: 500)
    }
    
    private func loadDroppedImage(providers: [NSItemProvider]) {
        if let provider = providers.first {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let image = NSImage(contentsOf: url) else {
                    return
                }
                DispatchQueue.main.async {
                    self.iconImage = image
                }
            }
        }
    }
    
    private func exportImage() {
        guard let image = iconImage else { return }
        
        let exportSize: CGFloat
        if isCustomSize {
            guard let width = Float(customWidth),
                  let height = Float(customHeight),
                  width > 0, height > 0 else {
                // 如果输入无效，不执行导出
                return
            }
            exportSize = CGFloat(width)
        } else {
            exportSize = targetSize
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let fileName = isCustomSize ? 
            "icon_\(customWidth)x\(customHeight).png" : 
            "icon_\(Int(exportSize))x\(Int(exportSize)).png"
        panel.nameFieldStringValue = fileName
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let size = isCustomSize ?
                    NSSize(width: Double(customWidth) ?? exportSize,
                          height: Double(customHeight) ?? exportSize) :
                    NSSize(width: exportSize, height: exportSize)
                
                let resizedImage = resizeImage(image, to: size)
                let finalImage = autoRoundCorners ? 
                    applyRoundCorners(resizedImage, radius: size.width * 0.1754) : 
                    resizedImage
                
                if let tiffData = finalImage.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapImage.representation(using: .png, properties: [
                       .interlaced: false,
                       .compressionFactor: 1.0
                   ]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
    
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        // 创建8位色深的位图上下文
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,        // 8位色深
            samplesPerPixel: 4,      // RGBA
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32         // 4通道 * 8位
        ) else { return image }
        
        // 设置绘图上下文
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        
        // 绘制图像
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0,
                  respectFlipped: true,
                  hints: [
                    .interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)
                  ])
        
        NSGraphicsContext.restoreGraphicsState()
        
        // 创建新图像
        let newImage = NSImage(size: size)
        newImage.addRepresentation(bitmapRep)
        
        return newImage
    }
    
    private func selectNewImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let newImage = NSImage(contentsOf: url) {
                    self.iconImage = newImage
                }
            }
        }
    }
    
    private func applyRoundCorners(_ image: NSImage, radius: CGFloat) -> NSImage {
        let size = image.size
        
        // 创建位图上下文
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else { return image }
        
        // 创建新的图像上下文
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        
        // 创建圆角路径
        let bezierPath = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), 
                                    xRadius: radius, 
                                    yRadius: radius)
        
        // 设置裁剪区域
        bezierPath.addClip()
        
        // 绘制原始图像
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // 创建新图像
        let newImage = NSImage(size: size)
        newImage.addRepresentation(bitmapRep)
        
        return newImage
    }
}

#Preview {
    ContentView()
}
