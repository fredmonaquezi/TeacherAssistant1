enum DerivationRunner {
    static func runAsync<Computation: Sendable, Result>(
        priority: TaskPriority = .userInitiated,
        compute: @escaping @Sendable () -> Computation,
        cancelledResult: @autoclosure () -> Result,
        makeResult: (Computation) -> Result
    ) async -> Result {
        if Task.isCancelled {
            return cancelledResult()
        }

        let computation = await Task.detached(priority: priority, operation: compute).value

        if Task.isCancelled {
            return cancelledResult()
        }

        return makeResult(computation)
    }
}
