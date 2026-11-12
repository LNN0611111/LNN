import SwiftUI

public struct SidebarView: View {
    @Binding public var project: BenchmarkProject
    public var isPlaying: Bool
    public var onPlay: () -> Void
    public var onReset: () -> Void
    public var onSaveProject: () -> Void
    public var onLoadProject: () -> Void
    public var onLoadSample: () -> Void
    
    public init(
        project: Binding<BenchmarkProject>,
        isPlaying: Bool,
        onPlay: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onSaveProject: @escaping () -> Void,
        onLoadProject: @escaping () -> Void,
        onLoadSample: @escaping () -> Void
    ) {
        self._project = project
        self.isPlaying = isPlaying
        self.onPlay = onPlay
        self.onReset = onReset
        self.onSaveProject = onSaveProject
        self.onLoadProject = onLoadProject
        self.onLoadSample = onLoadSample
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Header settings
                HeaderSection(
                    header: $project.header,
                    typography: $project.typography
                )
                
                // 2. Dimension columns settings
                DimensionSection(
                    dimensions: $project.dimensions,
                    container: $project.container,
                    typography: $project.typography
                )
                
                // 3. Data Items Management
                DataItemsSection(
                    items: $project.items,
                    dimensions: project.dimensions,
                    showAnnotationBorder: $project.container.showAnnotationBorder,
                    productColumnTitle: $project.container.productColumnTitle,
                    typography: $project.typography
                )
                
                // 4. Appearance, glass style, and background (with green screen and aspect ratio)
                AppearanceSection(
                    chartType: $project.chartType,
                    backgroundMode: $project.backgroundMode,
                    aspectRatio: $project.aspectRatio,
                    customMediaFilePath: $project.customMediaFilePath,
                    container: $project.container,
                    verticalConfig: $project.verticalConfig,
                    customVideoConfig: $project.customVideoConfig,
                    items: project.items,
                    animationDuration: project.animationConfig.duration
                )
                
                // 5. Animation physics and duration
                AnimationSection(
                    animation: $project.animationConfig,
                    isPlaying: isPlaying,
                    onPlay: onPlay,
                    onReset: onReset
                )
                
                // 6. Save / Load Project JSON
                ProjectSection(
                    onSave: onSaveProject,
                    onLoad: onLoadProject,
                    onLoadSample: onLoadSample
                )
            }
            .padding(14)
        }
        .background(Color(white: 0.08))
    }
}
