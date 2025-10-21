//
//  MetalDemoView.swift
//  MyMetal
//
//  Created by assistant on 20.10.25.
//

import SwiftUI

/// UI для настройки чувствительности жестов в CubeMetalView.
struct MetalDemoView: View {
    /// Чувствительность вращения куба (логарифмическая шкала, от 0.000001 до 0.1).
    @State private var rotationSensitivity: Double = 0.005
    /// Чувствительность импульса куба (логарифмическая шкала, от 0.0000001 до 0.01).
    @State private var velocitySensitivity: Double = 0.0001
    /// Таймер для дебouncing обновлений чувствительности.
    @State private var debounceTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Metal-рендеринг куба
                CubeMetalView(
                    rotationSensitivity: validatedFloat(rotationSensitivity),
                    velocitySensitivity: validatedFloat(velocitySensitivity)
                )
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.65)
                .background(Color.black.ignoresSafeArea())
                .accessibilityLabel("3D Cube View")

                // Форма с настройками
                Form {
                    Section(header: Text("Gesture Sensitivity").font(.headline)) {
                        // Настройка чувствительности вращения
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Rotation Sensitivity")
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                Text(String(format: "%.6f", rotationSensitivity))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { log10(rotationSensitivity) },
                                    set: { rotationSensitivity = pow(10, $0).clamped(to: 0.000001...0.1) }
                                ),
                                in: -6.0 ... -1.0,
                                step: 0.1
                            )
                            .accentColor(rotationSensitivity != 0.005 ? .orange : .blue)
                            .accessibilityLabel("Rotation Sensitivity Slider")
                            .onChange(of: rotationSensitivity) { _, _ in debounceUpdate() }
                        }

                        // Настройка чувствительности импульса
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Velocity Sensitivity")
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                Text(String(format: "%.6f", velocitySensitivity))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { log10(velocitySensitivity) },
                                    set: { velocitySensitivity = pow(10, $0).clamped(to: 0.0000001...0.01) }
                                ),
                                in: -7.0 ... -2.0,
                                step: 0.1
                            )
                            .accentColor(velocitySensitivity != 0.0001 ? .orange : .blue)
                            .accessibilityLabel("Velocity Sensitivity Slider")
                            .onChange(of: velocitySensitivity) { _, _ in debounceUpdate() }
                        }
                    }
                }
                .frame(maxHeight: geometry.size.height * 0.35)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // Поддержка Dynamic Type
            }
        }
        .ignoresSafeArea(.keyboard) // Предотвращает смещение при появлении клавиатуры
    }

    /// Проверяет и преобразует Double в Float, ограничивая значения.
    private func validatedFloat(_ value: Double) -> Float {
        let clamped = value.clamped(to: 0.0000001...0.1)
        return Float(clamped)
    }

    /// Дебouncing для ограничения частоты обновлений CubeMetalView.
    private func debounceUpdate() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            // Здесь можно добавить логику для уведомления CubeMetalView, если требуется
        }
    }
}

/// Расширение для ограничения значений в диапазоне.
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

struct MetalDemoView_Previews: PreviewProvider {
    static var previews: some View {
        #if targetEnvironment(simulator)
        Text("Metal preview not available in simulator")
            .font(.title)
            .foregroundColor(.red)
        #else
        MetalDemoView()
            .previewDevice("iPhone 14 Pro")
            .previewDisplayName("iPhone 14 Pro")
        #endif
    }
}
