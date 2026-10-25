import Testing
@testable import AmplayerCore

struct PlayModeTests {
    private func queue(_ n: Int) -> PlayQueue {
        var q = PlayQueue()
        q.replace(with: (0..<n).map { Track(sourceID: "local", path: "/\($0).mp3", title: "\($0)") }, startAt: 0)
        return q
    }

    /// 单曲播放：自然播完就停；手动下一首照常切换
    @Test func singlePlayStopsAfterCurrent() {
        var q = queue(3)
        q.repeatMode = .single
        #expect(q.nextIndex(auto: true) == nil)
        #expect(q.nextIndex(auto: false) == 1)
    }
}
