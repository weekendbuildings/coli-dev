import Foundation

/// The lab computes the same numbers as the lesson's program. / Тренажёр считает те же числа, что программа урока.
@main
enum InitNormVerification {
    private static func close(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) <= abs(expected) * 0.01
    }

    static func main() {
        let small = InitNormModel.run(scale: 0.25, normalized: false)
        precondition(close(small.activationSpread[0], 0.232) && close(small.activationSpread[7], 1.65e-5), "\(small.activationSpread)")
        let good = InitNormModel.run(scale: 1, normalized: false)
        precondition(close(good.activationSpread[0], 0.618) && close(good.activationSpread[7], 0.259), "\(good.activationSpread)")
        precondition(close(good.gradientSize[0], 0.384) && close(good.gradientSize[7], 0.265), "\(good.gradientSize)")
        let large = InitNormModel.run(scale: 4, normalized: false)
        precondition(close(large.gradientSize[0], 7.06) && close(large.gradientSize[7], 0.35), "\(large.gradientSize)")
        let normal = InitNormModel.run(scale: 4, normalized: true)
        precondition(close(normal.activationSpread[0], 0.629) && close(normal.gradientSize[0], 0.179), "\(normal.activationSpread)")
        precondition(InitNormModel.isHealthy(good), "Scale 1 is the healthy one. / Масштаб 1 здоровый.")
        precondition(!InitNormModel.isHealthy(small) && !InitNormModel.isHealthy(large), "The other two are not. / Два других нет.")
        for histogram in good.histograms {
            precondition(abs(histogram.reduce(0, +) - 1) < 1e-9, "Each layer's shares sum to one. / Доли слоя в сумме дают единицу.")
        }
        print("Init and normalization verified. / Инициализация и нормализация проверены.")
    }
}
