import Foundation

/// 最小要素を根に置く二分ヒープ。挿入・取り出しは O(log n) 回の比較で済む。
struct BinaryHeap<Element: Comparable & Sendable>: Sendable {
    private var elements: [Element] = []

    mutating func insert(_ element: Element) {
        elements.append(element)
        var child = elements.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard elements[child] < elements[parent] else { break }
            elements.swapAt(child, parent)
            child = parent
        }
    }

    mutating func popMinimum() -> Element? {
        guard let last = elements.popLast() else { return nil }
        guard let minimum = elements.first else { return last }
        elements[0] = last
        var parent = 0
        while 2 * parent + 1 < elements.count {
            var child = 2 * parent + 1
            let right = child + 1
            if right < elements.count && elements[right] < elements[child] {
                child = right
            }
            guard elements[child] < elements[parent] else { break }
            elements.swapAt(parent, child)
            parent = child
        }
        return minimum
    }
}
