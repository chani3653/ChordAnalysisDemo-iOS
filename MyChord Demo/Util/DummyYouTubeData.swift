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

    struct DummyVideoInfo {
        let videoId: String
        let title: String
        let artist: String
        let durationText: String
        let publishedAt: String
        let thumbnailURL: String
    }

    static let demoVideos: [DummyVideoInfo] = [
        DummyVideoInfo(
            videoId: "ItSKahBISg0",
            title: "YENA (최예나) - 캐치 캐치 (Catch Catch) MV",
            artist: "YENA(최예나)",
            durationText: "3:08",
            publishedAt: "2026.03.11",
            thumbnailURL: "https://i.ytimg.com/vi/NOiyDlWl534/hq720.jpg?sqp=-oaymwEnCNAFEJQDSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLBarP1A0oNkPM5MxhkCAEqKO5uFSQ"
        ),
        DummyVideoInfo(
            videoId: "CGj85pVzRJs",
            title: "The Beatles - Let It Be (Official Music Video) [Remastered 2015]",
            artist: "The Beatles",
            durationText: "4:02",
            publishedAt: "2024. 5. 10",
            thumbnailURL: "https://i.ytimg.com/vi/CGj85pVzRJs/hq720.jpg?sqp=-oaymwEnCNAFEJQDSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLCDovbQLwz-As5Jrlg1lrctoPjR-A"
        ),
        DummyVideoInfo(
            videoId: "vnS_jn2uibs",
            title: "DAY6(데이식스) \"한 페이지가 될 수 있게\" M/V",
            artist: "JYP Entertainment",
            durationText: "3:27",
            publishedAt: "2019. 7. 15",
            thumbnailURL: "https://i.ytimg.com/vi/oYvgISKD5Y8/hq720.jpg?sqp=-oaymwFBCNAFEJQDSFryq4qpAzMIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB8AEB-AH-CYAC0AWKAgwIABABGGUgTyhPMA8=&rs=AOn4CLDSwJeoCgrkhDGo-_wFcm6EWpbaLQ"
        ),
        DummyVideoInfo(
            videoId: "EkHTsc9PU2A",
            title: "Jason Mraz - I'm Yours (Official Video) [4K Remaster]",
            artist: "Jason Mraz",
            durationText: "3:41",
            publishedAt: "2008. 3. 15",
            thumbnailURL: "https://i.ytimg.com/vi/w5qOYi41WiA/hq720.jpg?sqp=-oaymwEnCNAFEJQDSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLCMd80hZPeCIfxeze5HLE14eros6Q"
        ),
        DummyVideoInfo(
            videoId: "wXTJBr9tt8Q",
            title: "The Beatles - Yesterday (Live With Spoken Word Intro, New York) [Remastered 2015]",
            artist: "The Beatles",
            durationText: "2:32",
            publishedAt: "2017. 12. 16",
            thumbnailURL: "https://i.ytimg.com/vi/wXTJBr9tt8Q/hq720.jpg?sqp=-oaymwEnCNAFEJQDSFryq4qpAxkIARUAAIhCGAHYAQHiAQoIGBACGAY4AUAB&rs=AOn4CLBwjyJQb7wzFOe_5ffhDS2G1DFd0g"
        ),
    ]

    struct DummyVideoItem {
        let searchItem: YouTubeSearchItem
        let videoId: String
        let durationText: String
    }

    static func makeItems(query _: String?, count: Int) -> [DummyVideoItem] {
        var items: [DummyVideoItem] = []
        items.reserveCapacity(count)

        for i in 0..<count {
            let video = demoVideos[i % demoVideos.count]

            let thumbnail = ThumbnailInfo(url: video.thumbnailURL, width: nil, height: nil)
            let thumbnails = Thumbnails(default: thumbnail, medium: thumbnail, high: thumbnail)

            let snippet = Snippet(
                publishedAt: video.publishedAt,
                channelId: nil,
                title: video.title,
                description: "This is dummy video data.",
                thumbnails: thumbnails,
                channelTitle: video.artist,
                liveBroadcastContent: nil,
                publishTime: nil
            )
            let id = VideoID(kind: "youtube#video", videoId: video.videoId, channelId: nil, playlistId: nil, rawId: nil)
            let item = YouTubeSearchItem(kind: "youtube#searchResult", etag: nil, id: id, snippet: snippet)

            items.append(DummyVideoItem(searchItem: item, videoId: video.videoId, durationText: video.durationText))
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

