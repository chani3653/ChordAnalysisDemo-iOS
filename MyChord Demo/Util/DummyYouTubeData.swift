//
//  DummyYouTubeData.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

struct DummyYouTubeData {

    static let totalCount = 100
    static let pageSize = 50
    static let defaultQuery = "Sample"

    struct DummyVideoItem {
        let searchItem: YouTubeSearchItem
        let videoId: String
        let durationText: String
    }

    static func makeItems(query: String?, count: Int) -> [DummyVideoItem] {
        let safeQuery = (query?.isEmpty == false) ? query! : defaultQuery
        var items: [DummyVideoItem] = []
        items.reserveCapacity(count)

        for index in 1...count {
            let videoId = "ItSKahBISg0"
            let title = "\(safeQuery) Dummy Song \(String(format: "%03d", index))"
            let channel = "Dummy Artist \(String(format: "%03d", index))"
            let durationText = makeDurationText(index: index)

            let snippet = Snippet(
                publishedAt: nil,
                channelId: nil,
                title: title,
                description: "This is dummy video data.",
                thumbnails: nil,
                channelTitle: channel,
                liveBroadcastContent: nil,
                publishTime: nil
            )
            let id = VideoID(kind: "youtube#video", videoId: videoId, channelId: nil, playlistId: nil, rawId: nil)
            let item = YouTubeSearchItem(kind: "youtube#searchResult", etag: nil, id: id, snippet: snippet)

            items.append(DummyVideoItem(searchItem: item, videoId: videoId, durationText: durationText))
        }

        return items
    }

    private static func makeDurationText(index: Int) -> String {
        let seconds = 60 + (index % 361)
        let minutesPart = seconds / 60
        let secondsPart = seconds % 60
        return String(format: "%d:%02d", minutesPart, secondsPart)
    }
}
private extension VideoID {
    init(kind: String?, videoId: String?, channelId: String?, playlistId: String?, rawId: String?) {
        self.kind = kind
        self.videoId = videoId
        self.channelId = channelId
        self.playlistId = playlistId
        self.rawId = rawId
    }
}

