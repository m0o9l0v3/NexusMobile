import Combine
import Foundation

@MainActor
final class HomeStore: ObservableObject {
    @Published private(set) var state: HomeViewState

    private let client: HomeClient

    init(client: HomeClient, initialState: HomeViewState = .idle) {
        self.client = client
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private func load() async {
        state = .loading

        do {
            let result = try await client.fetch()
            guard !Task.isCancelled else {
                state = .idle
                return
            }

            switch result {
            case .fresh(let snapshot):
                state = .loaded(snapshot)
            case .empty(let message):
                state = .empty(message)
            case .saved(let snapshot, let metadata):
                state = .saved(snapshot, metadata)
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(client.failureMessage)
        }
    }
}
