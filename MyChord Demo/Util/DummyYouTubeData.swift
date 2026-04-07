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
    static let demoVideoId = "ItSKahBISg0"
    static let demoTitle = "YENA(최예나) - '캐치 캐치' M/V"
    static let demoArtist = "YENA(최예나)"
    static let demoDurationText = "3:08"
    static let demoPublishedAt = "2026.03.11"
    static let demoThumbnailURL = "https://i.ytimg.com/vi/ItSKahBISg0/hq720.jpg?sqp=-oaymwEnCNAFEJQDSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLAXfIiTH_ZXxqNn6hGH-nnkSlqlew"

    struct DummyVideoItem {
        let searchItem: YouTubeSearchItem
        let videoId: String
        let durationText: String
    }

    static func makeItems(query _: String?, count: Int) -> [DummyVideoItem] {
        var items: [DummyVideoItem] = []
        items.reserveCapacity(count)

        let thumbnail = ThumbnailInfo(url: demoThumbnailURL, width: nil, height: nil)
        let thumbnails = Thumbnails(default: thumbnail, medium: thumbnail, high: thumbnail)

        for _ in 1...count {
            let title = demoTitle
            let channel = demoArtist
            let durationText = demoDurationText

            let snippet = Snippet(
                publishedAt: demoPublishedAt,
                channelId: nil,
                title: title,
                description: "This is dummy video data.",
                thumbnails: thumbnails,
                channelTitle: channel,
                liveBroadcastContent: nil,
                publishTime: nil
            )
            let id = VideoID(kind: "youtube#video", videoId: demoVideoId, channelId: nil, playlistId: nil, rawId: nil)
            let item = YouTubeSearchItem(kind: "youtube#searchResult", etag: nil, id: id, snippet: snippet)

            items.append(DummyVideoItem(searchItem: item, videoId: demoVideoId, durationText: durationText))
        }

        return items
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

