import Foundation

@main
enum LifeMechanismLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Synapse = SynapticPlasticityModel
        // NMDA passes calcium only when glutamate and strong depolarisation coincide.
        precondition(Synapse.nmdaPassesCalcium(glutamate: true, strongDepolarization: true))
        precondition(!Synapse.nmdaPassesCalcium(glutamate: true, strongDepolarization: false))
        precondition(!Synapse.nmdaPassesCalcium(glutamate: false, strongDepolarization: true))
        precondition(!Synapse.nmdaPassesCalcium(glutamate: false, strongDepolarization: false))

        let start = Synapse.startingAMPAReceptors
        precondition(Synapse.stimulate(ampaReceptors: start, glutamate: false, strongDepolarization: true) == (start, .noTransmitter))
        precondition(Synapse.stimulate(ampaReceptors: start, glutamate: true, strongDepolarization: false) == (start, .magnesiumBlock))
        let paired = Synapse.stimulate(ampaReceptors: start, glutamate: true, strongDepolarization: true)
        precondition(paired == (start + 1, .potentiation))
        // After potentiation the same glutamate release gives a larger response.
        precondition(Synapse.response(ampaReceptors: paired.receptors, glutamate: true) > Synapse.response(ampaReceptors: start, glutamate: true))
        precondition(Synapse.response(ampaReceptors: start, glutamate: false) == 0)
        // Glutamate alone never strengthens the synapse, however often it is repeated.
        var receptors = start
        for _ in 0..<20 { receptors = Synapse.stimulate(ampaReceptors: receptors, glutamate: true, strongDepolarization: false).receptors }
        precondition(receptors == start)
        // Repeated pairing strengthens up to the model's ceiling, then reports saturation.
        for _ in 0..<20 { receptors = Synapse.stimulate(ampaReceptors: receptors, glutamate: true, strongDepolarization: true).receptors }
        precondition(receptors == Synapse.maximumAMPAReceptors)
        precondition(Synapse.stimulate(ampaReceptors: receptors, glutamate: true, strongDepolarization: true).outcome == .saturated)

        typealias Enzyme = MichaelisMentenModel
        // Lesson quiz: Vmax 100 µmol/min, Km 2 mM, [S] 6 mM gives 75 µmol/min.
        precondition(close(Enzyme.rate(substrate: 6, maximumRate: 100, michaelisConstant: 2), 75))
        // Km is the concentration at half of Vmax.
        precondition(close(Enzyme.rate(substrate: 2, maximumRate: 100, michaelisConstant: 2), 50))
        // Practice task: 0.5, 2, 8, 50 mM give 20, 50, 80, and about 96.2; 90% of Vmax needs 9·Km = 18 mM.
        let practice = [0.5, 2, 8, 50].map { Enzyme.rate(substrate: $0, maximumRate: 100, michaelisConstant: 2) }
        precondition(close(practice[0], 20) && close(practice[1], 50) && close(practice[2], 80) && close(practice[3], 5000 / 52))
        precondition(close(Enzyme.shareOfMaximum(substrate: 18, michaelisConstant: 2), 0.9))
        // The rate never exceeds Vmax and grows with substrate.
        var previous = -1.0
        for step in 0...500 {
            let substrate = Double(step) * 0.1
            let rate = Enzyme.rate(substrate: substrate, maximumRate: 100, michaelisConstant: 2)
            precondition(rate < 100 && rate > previous)
            previous = rate
        }
        print("Synaptic plasticity and Michaelis–Menten lab models verified")
    }
}
