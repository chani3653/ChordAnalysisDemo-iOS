# MyChord Demo

YouTube 기반 음악 검색과 코드(Chord) 분석 결과 표시를 결합한 iOS 데모 앱입니다.  
사용자는 곡을 검색하고, 분석 가능 여부를 확인한 뒤, 서버에서 코드 분석 결과를 받아 타임라인 형태로 확인할 수 있습니다.  
또한 한 번 분석한 곡은 Realm 로컬 캐시에 저장하여 서버 연결이 불안정한 상황에서도 다시 열어볼 수 있도록 구성되어 있습니다.

---

## 프로젝트 개요

`MyChord Demo`는 다음 흐름을 중심으로 동작합니다.

1. YouTube Data API로 음악 영상을 검색합니다.
2. 검색 결과 중 영상 길이가 1분 이상 7분 미만인 항목만 추립니다.
3. 자체 분석 서버에 해당 영상의 분석 여부를 조회합니다.
4. 이미 분석된 곡이면 결과를 즉시 가져오고,
5. 미분석 곡이면 서버에 분석을 요청한 뒤 상태를 polling 하며 진행률을 표시합니다.
6. 분석이 완료되면 코드 타임라인을 플레이어 화면에 표시합니다.
7. 결과는 Realm에 저장하여 이후 오프라인 재사용이 가능하도록 합니다.

이 프로젝트는 단순한 YouTube 검색 앱이 아니라,
**검색 → 분석 요청 → 진행 상태 표시 → 결과 시각화 → 오프라인 캐시 재사용**까지 하나의 사용자 흐름으로 연결한 데모라는 점이 핵심입니다.

---

## 주요 기능

### 1. YouTube 음악 검색
- YouTube Search API를 사용해 음악 카테고리(videoCategoryId=10)의 영상을 검색합니다.
- 검색 결과는 페이지네이션(`nextPageToken`)을 지원합니다.
- 영상 상세 정보를 추가 조회하여 재생 시간을 함께 표시합니다.
- 1분 미만 또는 7분 이상 영상은 제외해 분석 대상 범위를 제한합니다.

### 2. 분석 가능 여부 확인
- 검색된 영상 ID 목록을 분석 서버의 `/videos/check` API로 전송합니다.
- 서버가 이미 분석 결과를 보유한 경우 목록에서 `분석됨` 상태를 보여줍니다.
- 상태 확인이 실패하면 `unknown` 상태로 처리하여 앱 흐름이 끊기지 않도록 구성했습니다.

### 3. 음악 분석 요청 및 상태 조회
- 사용자가 곡을 선택하면 `/analyze` API로 분석을 요청합니다.
- 서버 응답에 따라 다음 세 가지 경우를 처리합니다.
  - 즉시 결과 반환
  - 캐시된 결과 반환
  - 비동기 job 생성 후 polling 필요
- job이 생성되면 `/status/{jobId}` API를 주기적으로 호출하여 진행률을 확인합니다.
- 완료되면 `/result/{videoId}` API로 최종 결과를 불러옵니다.

### 4. 분석 진행 UI
- 로딩 오버레이를 사용해 현재 단계를 사용자에게 보여줍니다.
- 예시 단계:
  - 이미 분석한 곡인지 확인 중
  - 노래 다운로드 중
  - 코드 분석 중
  - 결과 정리 중
  - 완료
- 진행률이 있는 경우 퍼센트 값도 함께 표시합니다.

### 5. 플레이어 화면 + 코드 타임라인 표시
- `YouTubePlayerKit`을 사용해 YouTube 영상을 앱 내부에서 재생합니다.
- 분석 결과는 `ChordTimelineEntry` 배열로 변환되어 CollectionView에 표시됩니다.
- 현재 재생 시간에 맞춰 해당 코드 위치를 중심 정렬 기반 UI로 표시하도록 설계되어 있습니다.
- 재생/일시정지, 10초 이동, 슬라이더 탐색, 반복 구간(A-B) 기능이 포함되어 있습니다.

### 6. 오프라인 캐시
- 분석이 완료된 곡은 Realm에 저장됩니다.
- 저장 항목:
  - videoId
  - title
  - artist
  - thumbnailURL
  - durationText
  - chord 결과 목록(timeMs, chord, confidence)
  - analyzedAt
  - lastViewedAt
- 서버 연결 실패 시, 같은 곡이 로컬에 저장되어 있다면 캐시 데이터를 사용해 재생 화면을 열 수 있습니다.
- 검색 화면 상단에는 최근 본 곡 목록을 오프라인 진입점으로 활용할 수 있도록 구성되어 있습니다.

### 7. 설정 화면
- 아래 옵션들을 `UserDefaults` 기반으로 제어합니다.
  - 더미 데이터 사용
  - 배경 움직임
  - 서버 연결 on/off
  - 로딩 데모
- 실제 API 연결 전에도 UI 흐름을 테스트할 수 있도록 더미 데이터 기반 진입이 가능합니다.

---

## 기술 스택

### iOS
- Swift 5
- UIKit
- Storyboard / XIB
- UITableView / UICollectionView
- UserDefaults

### 네트워크 / 데이터
- Alamofire
- Codable
- RealmSwift

### 외부 서비스 / 라이브러리
- YouTube Data API
- YouTubePlayerKit
- Kingfisher

### 기타
- Swift Concurrency (`async/await`, `Task`)
- 커스텀 오버레이 뷰(Loading / Error)

---

## 폴더 구조

```bash
MyChord Demo
├── APIKeys.swift
├── AppDelegate.swift
├── SceneDelegate.swift
├── Info.plist
├── Model
│   ├── MusicAnalysisModels.swift
│   ├── YouTubeResponse.swift
│   └── YouTubeVideoDetailsResponse.swift
├── OfflineCache
│   ├── RealmSongCache.swift
│   └── OfflineSongCacheManager.swift
├── Util
│   ├── APIService.swift
│   ├── MusicAnalysisAPIService.swift
│   ├── NetworkManager.swift
│   ├── SettingsStore.swift
│   └── DummyYouTubeData.swift
├── View
│   ├── ErrorView
│   │   ├── ErrorView.swift
│   │   └── ErrorView.xib
│   └── LoadingView
│       ├── LoadingView.swift
│       └── LoadingView.xib
├── ViewController
│   ├── MainViewcontroller
│   │   ├── MainViewController.swift
│   │   ├── MainViewControllerExtension.swift
│   │   ├── Base.lproj
│   │   └── Cell
│   ├── PlayerViewController
│   │   ├── PlayerViewController.swift
│   │   ├── PlayerViewController+CollectionView.swift
│   │   ├── ChordTimelineDemo.swift
│   │   ├── CarouselFlowLayout.swift
│   │   ├── PlayerStoryboard.storyboard
│   │   └── Cell
│   ├── SettingsViewController
│   │   ├── SettingsViewController.swift
│   │   ├── SettingsViewController+TableView.swift
│   │   ├── SettingsViewController.storyboard
│   │   └── Cell
│   └── TabBarController
│       ├── TabBarViewController.swift
│       └── TabBarStoryboard.storyboard
└── Assets.xcassets
```

---

## 화면 구성

### 1. 검색 화면
- 검색어 입력
- YouTube 검색 결과 목록 표시
- 영상 썸네일 / 제목 / 채널명 / 날짜 / 길이 표시
- 분석 상태 표시 (`확인 전`, `확인중`, `분석됨`, `미분석`, `분석중 xx%`)
- 검색 결과가 아닌 경우 최근 오프라인 곡 목록 표시

### 2. 플레이어 화면
- YouTube 영상 재생
- 곡 정보 표시(제목, 아티스트, 썸네일)
- 재생 컨트롤
- 슬라이더 기반 탐색
- 코드 타임라인 표시
- 반복 구간 설정

### 3. 설정 화면
- 더미 데이터 모드
- 서버 연결 on/off
- 로딩 데모 UI 확인
- 기타 UI 옵션 설정

---

## 핵심 동작 흐름

### 검색 흐름
1. 사용자가 검색어 입력
2. `APIService.searchYouTube()` 호출
3. 검색된 `videoId` 목록 추출
4. `APIService.fetchVideoDetails()`로 duration 조회
5. duration 필터링 후 목록 모델 생성
6. `MusicAnalysisAPIService.checkAnalyzed()`로 분석 여부 조회
7. 셀 상태 업데이트

### 분석 흐름
1. 사용자가 영상 선택
2. 현재 상태가 `available`이면 즉시 결과 조회
3. 아니면 `/analyze` 요청
4. `jobId`가 있으면 `/status/{jobId}` polling
5. 완료 시 `/result/{videoId}` 조회
6. 결과를 Realm에 저장
7. Player 화면으로 이동

### 오프라인 fallback 흐름
1. 분석 도중 서버 에러 발생
2. 동일한 `videoId`가 Realm에 저장되어 있는지 확인
3. 저장되어 있으면 캐시 데이터로 Player 화면 진입
4. 저장되어 있지 않으면 연결 실패 알림 표시

---

## 주요 클래스 설명

### `APIService`
YouTube 검색 및 영상 상세 정보 조회를 담당합니다.

- `searchYouTube(query:videoDuration:pageToken:)`
- `fetchVideoDetails(videoIds:)`

### `MusicAnalysisAPIService`
코드 분석 서버와의 통신을 담당합니다.

- `checkAnalyzed(videoIDs:)`
- `analyze(youtubeURL:)`
- `fetchStatus(jobID:)`
- `fetchResult(videoID:)`

### `NetworkManager`
Alamofire 기반 공통 네트워크 계층입니다.

- GET / POST / PUT / DELETE 요청 래핑
- Decodable 응답 처리
- 에러 파싱
- 에러 알림 브로드캐스트 및 오버레이 표시

### `OfflineSongCacheManager`
Realm 기반 로컬 캐시 관리 클래스입니다.

- 분석 결과 저장
- 단건 조회
- 최근 곡 목록 조회
- 최근 조회 시각 갱신
- 캐시 삭제

### `MainViewController`
앱의 핵심 진입 화면입니다.

- 검색 수행
- 무한 스크롤 기반 추가 로딩
- 분석 상태 반영
- 분석 요청 시작
- 오프라인 목록 표시
- Player 화면 전환

### `PlayerViewController`
곡 재생 및 코드 표시 화면입니다.

- YouTube 영상 재생
- 현재 시간 추적
- 코드 타임라인 렌더링
- 반복 재생 구간 설정
- 슬라이더 탐색 처리

### `SettingsStore`
사용자 설정을 `UserDefaults`로 저장/조회합니다.

---

## 데이터 모델

### YouTube 관련 모델
- `YouTubeSearchResponse`
- `YouTubeSearchItem`
- `Snippet`
- `YouTubeVideoListResponse`
- `YouTubeVideoItem`
- `ContentDetails`

### 분석 서버 관련 모델
- `VideoAnalysisAvailability`
- `AnalyzeResponse`
- `AnalysisJobStatusResponse`
- `AnalysisResultResponse`
- `AnalysisVideoMeta`
- `AnalysisChordResult`

### 앱 내부 표시 모델
- `ChordTimelineEntry`
- `MainViewController.VideoItemViewModel`

### Realm 모델
- `RealmAnalyzedSong`
- `RealmChordEntry`

---

## 실행 방법

### 1. 사전 준비
- Xcode 설치
- iOS 15.6 이상 권장
- Swift Package Manager 의존성 설치 가능 환경
- YouTube Data API Key 발급
- 음악 분석 서버 실행

### 2. API Key 설정
현재 프로젝트에는 `APIKeys.swift`에 YouTube API Key를 직접 넣는 형태로 작성되어 있습니다.

```swift
enum APIKeys {
    static let youtubeAPIKey = "YOUR_API_KEY"
}
```

실제 공개 저장소에서는 다음 방식 중 하나로 분리하는 것을 권장합니다.
- `.xcconfig`
- 환경 변수 주입
- gitignore 처리된 별도 설정 파일

### 3. 분석 서버 주소 설정
`MusicAnalysisAPIService.swift`에서 서버 주소를 수정합니다.

```swift
private enum API {
    static let baseURL = "http://192.168.0.12:3000"
}
```

로컬 네트워크 환경 또는 배포 환경에 맞게 변경해야 합니다.

### 4. 의존성 설치
프로젝트는 Swift Package Manager를 사용합니다.

주요 패키지:
- Alamofire
- Kingfisher
- YouTubePlayerKit
- RealmSwift

Xcode에서 프로젝트를 열면 패키지가 자동으로 resolve 됩니다.

### 5. 실행
1. `MyChord Demo.xcodeproj` 열기
2. Signing 설정 확인
3. 대상 디바이스 선택
4. Run

---

## 서버 API 가정

코드 기준으로 앱은 아래 API 계약을 기대합니다.

### 1. 분석 여부 확인
`POST /videos/check`

Request:
```json
{
  "video_ids": ["abc123", "def456"]
}
```

Response:
```json
[
  {
    "video_id": "abc123",
    "analyzed": true
  },
  {
    "video_id": "def456",
    "analyzed": false
  }
]
```

### 2. 분석 요청
`POST /analyze`

Request:
```json
{
  "youtube_url": "https://www.youtube.com/watch?v=abc123"
}
```

Possible Response:
```json
{
  "video_id": "abc123",
  "job_id": 12,
  "status": "downloading",
  "progress": 10
}
```

또는 캐시/즉시 결과가 포함된 응답이 올 수 있도록 설계되어 있습니다.

### 3. 상태 조회
`GET /status/{jobId}`

Response:
```json
{
  "job_id": 12,
  "video_id": "abc123",
  "status": "analyzing",
  "progress": 60
}
```

### 4. 최종 결과 조회
`GET /result/{videoId}`

Response:
```json
{
  "video_id": "abc123",
  "video": {
    "video_id": "abc123",
    "title": "Sample Song",
    "thumbnail": "https://..."
  },
  "results": [
    {
      "time_ms": 0,
      "chord": "C",
      "confidence": 0.98
    },
    {
      "time_ms": 1520,
      "chord": "G",
      "confidence": 0.95
    }
  ]
}
```

---

## 프로젝트에서 눈에 띄는 설계 포인트

### 1. 온라인/오프라인 흐름을 자연스럽게 연결
서버 연결이 실패하더라도, 이미 분석했던 곡은 로컬 캐시로 열 수 있도록 설계되어 있어 데모 이상의 실사용 가능성을 보여줍니다.

### 2. 사용자 상태 피드백을 적극 반영
분석 단계별 메시지와 진행률을 UI에 표시하여, 백그라운드 작업이 길어질 수 있는 음악 분석의 특성을 보완하고 있습니다.

### 3. API 계층 분리
YouTube API와 자체 분석 서버 API를 각각 `APIService`, `MusicAnalysisAPIService`로 나누어 책임을 분리했습니다.

### 4. 네트워크 공통화
`NetworkManager`에서 요청/응답/에러 처리를 공통화하여 중복을 줄이고 확장 가능성을 확보했습니다.

### 5. 재생 UI와 코드 타임라인 결합
단순 텍스트 리스트가 아니라 플레이어와 타임라인 UI를 결합해 사용자 경험을 강화하려는 의도가 잘 드러납니다.

---

## 개선 포인트

### 1. API Key 노출 제거
현재 `APIKeys.swift`에 실제 YouTube API Key가 직접 포함되어 있습니다.  
공개 저장소에는 절대 그대로 올리지 않는 것이 좋습니다.

### 2. 서버 URL 하드코딩 제거
`192.168.x.x` 형태의 내부망 주소가 코드에 직접 들어가 있어 환경 전환이 어렵습니다.  
설정 파일 또는 Build Configuration으로 분리하는 것이 좋습니다.

### 3. README에 서버 저장소 링크 추가
이 프로젝트는 분석 서버가 함께 있어야 기능이 완성됩니다.  
서버 저장소가 있다면 README에 함께 링크해 주는 것이 좋습니다.

### 4. 아키텍처 문서화 강화
현재는 ViewController 중심 구조입니다.  
README에 MVC 구조 또는 향후 MVVM 전환 계획을 적어두면 프로젝트 설명이 더 좋아집니다.

### 5. 스크린샷 추가
GitHub README에서는 실제 화면 캡처가 있으면 이해도가 크게 올라갑니다.
- 검색 화면
- 분석 로딩 화면
- 플레이어 화면
- 오프라인 목록 화면

### 6. 테스트 코드 보강
현재 압축본 기준으로 별도 테스트 타깃이나 테스트 코드 구조는 확인되지 않았습니다.  
네트워크/파싱/캐시 계층은 테스트 추가 여지가 큽니다.

---

## 향후 확장 아이디어

- 로컬 음원 파일 분석 지원
- 곡 즐겨찾기 / 최근 분석 목록 고정
- 코드 진행 즐겨찾기 저장
- 분석 실패 사유 상세 표시
- 백엔드 job queue 상태 시각화
- 분석 정확도(confidence) 기반 UI 강조
- 특정 구간 반복 연습 기능 강화
- 오프라인 전용 라이브러리 화면 구성

---

## 참고 사항

이 README는 첨부된 압축 파일의 **iOS 소스코드 구조를 직접 확인한 뒤 작성한 초안**입니다.  
실제 서버 구현, 빌드 실행 결과, 스크린샷, 배포 방식은 압축본 안에서 함께 확인되지 않은 부분이 있어,
해당 내용은 코드에 드러난 범위까지만 반영했습니다.

---

## License

필요 시 추가

```text
MIT / Apache-2.0 / Private
```

프로젝트 공개 범위에 맞게 선택해서 작성하면 됩니다.
