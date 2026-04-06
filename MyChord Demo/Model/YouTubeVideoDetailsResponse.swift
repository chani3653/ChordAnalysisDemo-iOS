//
//  YouTubeVideoDetailsResponse.swift
//  MyChord Demo
//
//  Created by Chan Hwi Park on 4/6/26.
//

import Foundation

struct YouTubeVideoListResponse: Decodable {
    let kind: String?
    let etag: String?
    let items: [YouTubeVideoItem]
    let pageInfo: PageInfo?
}

struct YouTubeVideoItem: Decodable {
    let kind: String?
    let etag: String?
    let id: String?
    let contentDetails: ContentDetails?
}

struct ContentDetails: Decodable {
    let duration: String?
    let dimension: String?
    let definition: String?
    let caption: String?
    let licensedContent: Bool?
}
