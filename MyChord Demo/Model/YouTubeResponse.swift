//
//  YouTubeResponse.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

struct YouTubeSearchResponse: Decodable {
    let kind: String?
    let etag: String?
    let nextPageToken: String?
    let regionCode: String?
    let pageInfo: PageInfo?
    let items: [YouTubeSearchItem]
}

struct PageInfo: Decodable {
    let totalResults: Int?
    let resultsPerPage: Int?
}

struct YouTubeSearchItem: Decodable {
    let kind: String?
    let etag: String?
    let id: VideoID
    let snippet: Snippet
}

struct VideoID: Decodable {
    let kind: String?
    let videoId: String?
    let channelId: String?
    let playlistId: String?
    let rawId: String?

    var videoIdValue: String? {
        return videoId ?? rawId ?? channelId ?? playlistId
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(), let id = try? singleValue.decode(String.self) {
            kind = nil
            videoId = nil
            channelId = nil
            playlistId = nil
            rawId = id
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        channelId = try container.decodeIfPresent(String.self, forKey: .channelId)
        playlistId = try container.decodeIfPresent(String.self, forKey: .playlistId)
        rawId = nil
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case videoId
        case channelId
        case playlistId
    }
}

struct Snippet: Decodable {
    let publishedAt: String?
    let channelId: String?
    let title: String?
    let description: String?
    let thumbnails: Thumbnails?
    let channelTitle: String?
    let liveBroadcastContent: String?
    let publishTime: String?
}

struct Thumbnails: Decodable {
    let `default`: ThumbnailInfo?
    let medium: ThumbnailInfo?
    let high: ThumbnailInfo?
}

struct ThumbnailInfo: Decodable {
    let url: String?
    let width: Int?
    let height: Int?
}


