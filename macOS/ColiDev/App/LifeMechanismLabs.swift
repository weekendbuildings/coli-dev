import Foundation

/// Long-term potentiation as described in the biology lesson on synaptic plasticity (OpenStax Biology 2e, 35.2):
/// NMDA receptors pass calcium only when glutamate is released and the postsynaptic cell is strongly depolarised,
/// which pushes out the magnesium block; calcium entry inserts extra AMPA receptors, so the same glutamate release
/// then causes a larger response. Receptor counts are schematic units, not measured numbers.
enum SynapticPlasticityModel {
    static let startingAMPAReceptors = 3
    static let maximumAMPAReceptors = 10

    enum Outcome: Equatable {
        /// No glutamate was released, so neither AMPA nor NMDA receptors respond.
        case noTransmitter
        /// Glutamate opens AMPA receptors, but magnesium still blocks NMDA: a response without strengthening.
        case magnesiumBlock
        /// Glutamate and strong depolarisation together: calcium enters and one AMPA receptor is inserted.
        case potentiation
        /// Potentiation happened earlier up to the model's ceiling; the synapse cannot strengthen further here.
        case saturated
    }

    static func nmdaPassesCalcium(glutamate: Bool, strongDepolarization: Bool) -> Bool {
        glutamate && strongDepolarization
    }

    /// Response to a glutamate release in schematic units: one unit per AMPA receptor.
    static func response(ampaReceptors: Int, glutamate: Bool) -> Int { glutamate ? ampaReceptors : 0 }

    static func stimulate(ampaReceptors: Int, glutamate: Bool, strongDepolarization: Bool) -> (receptors: Int, outcome: Outcome) {
        guard glutamate else { return (ampaReceptors, .noTransmitter) }
        guard nmdaPassesCalcium(glutamate: glutamate, strongDepolarization: strongDepolarization) else {
            return (ampaReceptors, .magnesiumBlock)
        }
        guard ampaReceptors < maximumAMPAReceptors else { return (ampaReceptors, .saturated) }
        return (ampaReceptors + 1, .potentiation)
    }
}

/// Michaelis–Menten kinetics for the chemistry lesson: v = Vmax · [S] / (Km + [S]).
enum MichaelisMentenModel {
    static let substrateRange = 0.0...50.0     // mM
    static let michaelisRange = 0.5...10.0     // mM
    static let maximumRateRange = 50.0...200.0 // µmol/min

    static func rate(substrate: Double, maximumRate: Double, michaelisConstant: Double) -> Double {
        guard substrate > 0 else { return 0 }
        return maximumRate * substrate / (michaelisConstant + substrate)
    }

    static func shareOfMaximum(substrate: Double, michaelisConstant: Double) -> Double {
        rate(substrate: substrate, maximumRate: 1, michaelisConstant: michaelisConstant)
    }
}
