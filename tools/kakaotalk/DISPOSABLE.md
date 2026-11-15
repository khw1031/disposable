---
type: skill
license: CC0-1.0
maintainers: khw1031
added: 2026-11-13
device: mac
language: ko
tags: kakaotalk, macos, accessibility, messaging, launchd
summary_en: Works with the KakaoTalk desktop app on macOS through the Accessibility API: reads chats as JSON, sends messages, and schedules timed or repeating sends with launchd, mostly in the background.
description_en: Works with the KakaoTalk desktop app on macOS through the Accessibility (AX) API: reads chat lists and conversations as JSON (dates and photos are filled in by OCR of window captures), sends messages, and schedules sends at a set time or on a repeat with launchd. It mostly works in the background without bringing KakaoTalk to the front. Use it for requests such as "read my KakaoTalk chat", "get KakaoTalk messages", "send a KakaoTalk message", "schedule a KakaoTalk message" or "send a KakaoTalk message every morning". Because it really sends messages, it sends or schedules only when the person names the chat and the text. Not for KakaoTalk for Windows, mobile, the Kakao API or chatbots, or decrypting the encrypted local database.
summary_ja: macOS のカカオトーク デスクトップアプリをアクセシビリティ API で操作し、会話を JSON で読み取り、メッセージを送信し、launchd で指定時刻・定期送信を予約します。主にバックグラウンドで動きます。
description_ja: macOS のカカオトーク デスクトップアプリをアクセシビリティ(AX) API で操作します。チャット一覧と会話内容を JSON で読み取り(日付・写真はウィンドウキャプチャの OCR で補完)、メッセージを送信し、launchd で指定時刻・定期の送信を予約します。ほとんどの場合、カカオトークを前面に出さずバックグラウンドで動きます。「カトクの会話を読んで」「カカオトークのメッセージを取ってきて」「カトクを送って」「カトクを予約送信」「毎朝カトクを送る」といった依頼に使います。実際にメッセージを送るスキルなので、送信・予約はユーザーがチャットと文面を明示したときだけ行います。カカオトークの PC 版(Windows)、モバイル、Kakao API・チャットボット、暗号化されたローカル DB の復号には使いません。
summary_zh_hans: 通过辅助功能 API 操作 macOS 上的 KakaoTalk 桌面应用：以 JSON 读取对话、发送消息，并用 launchd 预约定时或周期发送，主要在后台运行。
description_zh_hans: 通过辅助功能(AX) API 操作 macOS 上的 KakaoTalk 桌面应用：以 JSON 读取聊天列表和对话内容(日期和照片通过窗口截图 OCR 补充)，发送消息，并用 launchd 预约在指定时间或周期发送。大多数情况下无需把 KakaoTalk 切到前台，在后台运行。适用于“读一下 KakaoTalk 对话”“获取 KakaoTalk 消息”“发 KakaoTalk 消息”“预约发送 KakaoTalk”“每天早上发 KakaoTalk”等请求。由于会真的发送消息，只有在用户明确指定聊天和内容时才发送或预约。不用于 KakaoTalk Windows 版、手机版、Kakao API 与聊天机器人，也不解密加密的本地数据库。
summary_zh_hant: 透過輔助使用 API 操作 macOS 上的 KakaoTalk 桌面應用程式：以 JSON 讀取對話、傳送訊息，並用 launchd 預約定時或週期傳送，主要在背景執行。
description_zh_hant: 透過輔助使用(AX) API 操作 macOS 上的 KakaoTalk 桌面應用程式：以 JSON 讀取聊天列表與對話內容(日期與照片以視窗截圖 OCR 補充)，傳送訊息，並用 launchd 預約在指定時間或週期傳送。多數情況下不必把 KakaoTalk 切到前景，在背景執行。適用於「讀一下 KakaoTalk 對話」「取得 KakaoTalk 訊息」「傳 KakaoTalk 訊息」「預約傳送 KakaoTalk」「每天早上傳 KakaoTalk」等請求。由於會真的傳送訊息，只有在使用者明確指定聊天室與內容時才傳送或預約。不用於 KakaoTalk Windows 版、手機版、Kakao API 與聊天機器人，也不解密加密的本機資料庫。
---

## Limits

macOS의 카카오톡 Mac(App Store) 앱에서만 동작한다. 카카오톡이 화면 구조를 바꾸면 읽기·전송이 깨질 수 있다. 대화로 받은 파일(PDF·문서 등)은 내려받지 않는다. 사진은 원본이 아니라 화면 캡처를 OCR로 읽고, `--media-dir`로 그 캡처를 남길 수 있다. 메시지를 실제로 보내므로 시험은 나와의 채팅으로 하고, 반복·대량 전송은 하지 않는다(카카오 운영정책이 비정상적인 자동 전송을 제한할 수 있다).
