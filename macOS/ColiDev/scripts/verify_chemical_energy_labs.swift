import Foundation

@main
enum ChemicalEnergyLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Coupling = EnergyCouplingModel
        // Lesson quiz: +20 kJ/mol coupled to one ATP gives −10.5 kJ/mol, so the process runs.
        precondition(close(Coupling.total(reaction: 20, atpCount: 1), -10.5) && Coupling.runs(reaction: 20, atpCount: 1))
        precondition(!Coupling.runs(reaction: 20, atpCount: 0))
        // Practice task: +12 needs one ATP, +45 needs at least two.
        precondition(Coupling.minimumATP(reaction: 12) == 1 && Coupling.minimumATP(reaction: 45) == 2)
        precondition(!Coupling.runs(reaction: 45, atpCount: 1) && Coupling.runs(reaction: 45, atpCount: 2))
        // Exactly 30.5 kJ/mol is not enough with one ATP: the total must be negative, not zero.
        precondition(Coupling.minimumATP(reaction: 30.5) == 2)
        for reaction in stride(from: 1.0, through: 100, by: 0.5) {
            let needed = Coupling.minimumATP(reaction: reaction)
            precondition(Coupling.runs(reaction: reaction, atpCount: needed) && !Coupling.runs(reaction: reaction, atpCount: needed - 1))
        }

        typealias Equilibrium = ReactionQuotientModel
        // Lesson task: Q = 0.0040² / 0.020² = 0.040 < K = 0.64, so the reaction runs forward.
        let lesson = Equilibrium.lessonMixture
        precondition(close(Equilibrium.quotient(lesson), 0.040) && Equilibrium.direction(lesson) == .forward)
        let settled = Equilibrium.equilibrate(lesson)
        precondition(close(Equilibrium.quotient(settled), 0.64, 1e-9) && Equilibrium.direction(settled) == .equilibrium)
        precondition(settled.carbonDioxide > lesson.carbonDioxide && settled.water < lesson.water)
        // Atoms are conserved: every CO and H₂O used becomes one CO₂ and one H₂.
        precondition(close(settled.carbonMonoxide + settled.carbonDioxide, lesson.carbonMonoxide + lesson.carbonDioxide))
        // Le Châtelier: adding water to an equilibrium mixture lowers Q below K and shifts it forward again.
        var disturbed = settled
        disturbed.water += 0.02
        precondition(Equilibrium.direction(disturbed) == .forward)
        precondition(Equilibrium.equilibrate(disturbed).hydrogen > settled.hydrogen)
        // A product-rich mixture runs in reverse.
        let productRich = Equilibrium.Mixture(carbonMonoxide: 0.005, water: 0.005, carbonDioxide: 0.03, hydrogen: 0.03)
        precondition(Equilibrium.direction(productRich) == .reverse)
        precondition(Equilibrium.equilibrate(productRich).carbonDioxide < productRich.carbonDioxide)
        print("Energy coupling and reaction quotient lab models verified")
    }
}
