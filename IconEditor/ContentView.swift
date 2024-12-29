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
    
    let availableSizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]
    
    var body: some View {
        HStack(alignment:.top, spacing: 50){
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
            VStack(alignment:.leading, spacing: 20) {
                Text("目标尺寸:")
                Picker("", selection: $targetSize) {
                    ForEach(availableSizes, id: \.self) { size in
                        Text("\(Int(size))x\(Int(size))")
                    }
                }
                .pickerStyle(.radioGroup)
                
                Button(action: exportImage) {
                    Label("导出图标", systemImage: "square.and.arrow.up")
                        .frame(width: 120)
                }
                .disabled(iconImage == nil)
                .buttonStyle(.borderedProminent)
                .padding(.top, 20)
            }
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
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "icon_\(Int(targetSize))x\(Int(targetSize)).png"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let resizedImage = resizeImage(image, to: NSSize(width: targetSize, height: targetSize))
                if let tiffData = resizedImage.tiffRepresentation,
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
}

#Preview {
    ContentView()
}
