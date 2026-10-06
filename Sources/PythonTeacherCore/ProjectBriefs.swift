import Foundation

/// An app-owned, synthetic project objective for project-scope practice. A brief becomes available once
/// the learner reaches its earliest suitable chapter; later chapters reuse it through their own focus.
public struct ProjectBrief: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let objective: String
    public let minimumChapterID: String

    public init(id: String, title: String, objective: String, minimumChapterID: String) {
        self.id = id
        self.title = title
        self.objective = objective
        self.minimumChapterID = minimumChapterID
    }

    /// Briefs whose earliest chapter is the given chapter or within its prerequisite closure, in catalog order.
    public static func available(for chapter: Chapter, curriculum: [Chapter] = Curriculum.chapters) -> [ProjectBrief] {
        guard let scoped = CurriculumGraph(curriculum).closureIncludingSelf(of: chapter.id) else { return [] }
        let ids = Set(scoped.map(\.id))
        return catalog.filter { ids.contains($0.minimumChapterID) }
    }

    public static let catalog: [ProjectBrief] = [
        ProjectBrief(id: "project-cafe-receipt", title: "Café receipt",
            objective: "A small café prints a receipt for one order. Item prices and quantities become a subtotal, a service charge and a total, followed by neatly formatted receipt lines a customer could read.",
            minimumChapterID: "values"),
        ProjectBrief(id: "project-vending-machine", title: "Vending machine",
            objective: "A snack vending machine accepts coins, looks up the price of the chosen slot, returns the correct change, and refuses the sale when the money or the stock is not enough.",
            minimumChapterID: "decisions"),
        ProjectBrief(id: "project-cinema-tickets", title: "Cinema ticket desk",
            objective: "A cinema ticket desk prices tickets from the visitor's age, the day of the week and membership, and rejects impossible requests such as a negative age.",
            minimumChapterID: "decisions"),
        ProjectBrief(id: "project-savings-goal", title: "Savings goal tracker",
            objective: "Someone saves a fixed amount each week toward a goal. The tracker shows the running balance week by week, how many weeks the goal takes, and what happens when a week is skipped.",
            minimumChapterID: "loops"),
        ProjectBrief(id: "project-parking-garage", title: "Parking garage fees",
            objective: "A parking garage charges by the time between entry and exit, with a free grace period, an hourly rate and a daily maximum, and produces a short summary of the day's tickets.",
            minimumChapterID: "functions"),
        ProjectBrief(id: "project-library-checkout", title: "Library checkout desk",
            objective: "A small library tracks which books are on the shelf and who has borrowed what. It handles checkouts, returns and a report of overdue loans for a synthetic list of members.",
            minimumChapterID: "collections"),
        ProjectBrief(id: "project-text-adventure", title: "Tiny text adventure",
            objective: "A tiny adventure game has rooms joined by named exits. Given a list of moves, it reports the room the player ends in, the path they took, and which moves were blocked.",
            minimumChapterID: "collections"),
        ProjectBrief(id: "project-gradebook", title: "Gradebook checker",
            objective: "A teacher's gradebook arrives as records that may contain mistakes. The checker rejects invalid records with a clear reason and summarizes the valid ones.",
            minimumChapterID: "reliability"),
        ProjectBrief(id: "project-warehouse-restock", title: "Warehouse restock list",
            objective: "A warehouse pairs each item with its stock level and reorder threshold, then builds the restock list with quantities to order, ranked by urgency.",
            minimumChapterID: "iteration"),
        ProjectBrief(id: "project-sales-report", title: "Shop sales report",
            objective: "A shop saves synthetic sales rows to a file in the working folder, reads them back, and writes a daily totals report that someone could open later.",
            minimumChapterID: "files"),
        ProjectBrief(id: "project-bank-ledger", title: "Bank account ledger",
            objective: "A bank account records deposits and withdrawals, refuses overdrafts, and prints a statement of every transaction with the running balance.",
            minimumChapterID: "classes"),
        ProjectBrief(id: "project-weather-station", title: "Weather station cleanup",
            objective: "A weather station sends messy temperature readings with gaps and typos. Clean them into trustworthy rows and summarize each day for a short report.",
            minimumChapterID: "ds-cleaning")
    ]
}
