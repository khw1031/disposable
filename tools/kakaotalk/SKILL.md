---
name: kakaotalk
description: macOS 카카오톡 데스크톱 앱을 접근성(AX) API로 다룬다 — 채팅 목록과 대화 내용을 JSON으로 읽고(날짜·사진은 창 캡처 OCR로 보완), 메시지를 전송하고, launchd로 특정 시각·주기 전송을 예약한다. 대부분 카카오톡을 앞으로 띄우지 않고 백그라운드에서 동작한다. "카톡 대화 읽어줘", "카카오톡 메시지 가져와", "카톡 보내줘", "카톡 예약 전송", "매일 아침 카톡 보내기" 요청에 사용한다. 메시지를 실제로 전송하는 스킬이므로 전송·예약은 사용자가 방과 문구를 명시했을 때만 실행한다. 카카오톡 PC 버전(Windows), 모바일, 카카오 API·챗봇, 암호화된 로컬 DB 복호화에는 쓰지 않는다.
compatibility: macOS + 카카오톡 Mac(App Store) 실행·로그인 상태, Xcode Command Line Tools(swiftc), Python 3.9+ 표준 라이브러리. 터미널 앱에 손쉬운 사용(필수)·화면 기록(OCR 보완 시) 권한, 예약 전송은 빌드된 `KakaoTalkSkillAX.app` 자체에 손쉬운 사용 권한 필요.
---

# KakaoTalk

CLI는 `scripts/kakaotalk`(스킬 디렉토리 기준 절대 경로로 실행)이고 모든 출력은 stdout JSON이다.
접근성 처리는 `scripts/kakaotalk-ax.swift`를 빌드한 바이너리가 맡는다. 바이너리·예약 작업·로그는 스킬 밖
`~/Library/Application Support/kakaotalk-skill/`, `~/Library/Logs/kakaotalk-skill/`, `~/Library/LaunchAgents/`에만 둔다.

## Boundary

- **전송·예약은 명시 요청만.** 사용자가 방 이름과 문구를 말했을 때만 `kakaotalk send`/`kakaotalk schedule add`를 실행한다. 실행 전에
  방 이름·문구·시각(예약)을 한 줄로 되읽어 확인받는다. 문구를 지어내거나 다른 방으로 바꾸지 않는다.
- **시험은 나와의 채팅(`--self`)으로.** 동작 확인용 전송·예약은 다른 방에 하지 않는다.
- **읽음 처리 부작용.** 안 읽은 메시지가 있는 방을 열면 읽음 처리된다. CLI는 기본으로 거부하며
  `--allow-unread`는 사용자가 그 방을 열라고 명시했을 때만 붙인다.
- **주기 예약은 종료 조건 필수**(`--max-runs` 또는 `--until`). 타인 방 주기 전송은 횟수·간격을 사용자와 확정한다.
- 읽은 대화 내용은 stdout으로만 돌려준다. 파일 저장(`--media-dir`)은 사용자가 요청할 때만, git 저장소·동기화 폴더 밖에.
- 로컬 DB 복호화, 앱 바이너리 변조, 디버거 부착은 하지 않는다(서명·샌드박스 우회).

## Setup (처음 한 번)

1. `kakaotalk doctor` — `swiftc`, 바이너리(없으면 자동 빌드), 터미널 손쉬운 사용 권한, 카카오톡 실행, 화면 기록 권한을 본다.
2. 예약 전송을 쓸 때만: `kakaotalk doctor --launchd`. `trusted: false`면 사용자가 시스템 설정 → 개인정보 보호 및 보안 →
   손쉬운 사용 → `+`에서 출력의 `app` 경로(`KakaoTalkSkillAX.app`, ⌘⇧G로 경로 입력)를 추가하고 켜야 한다(대신 할 수 없다).
   앱 번들이 아닌 명령줄 바이너리는 목록이 무시했다 — 그래서 바이너리를 앱 번들로 감싼다.
3. `swift` 소스를 고친 뒤에만 `kakaotalk build`. 앱이 다시 서명되면 권한이 풀릴 수 있다 — 2번을 다시 확인하고,
   필요하면 목록에서 지운 뒤 다시 추가한다.

## Workflow

1. **목록**: `kakaotalk rooms` → 방 이름·안 읽은 수·시간·미리보기·`self`(나와의 채팅). 미리보기만으로 답이 되면 방을 열지 않는다.
2. **읽기**: `kakaotalk read --room "<방>" [--pages N] [--dates] [--media] [--close]`
   - `--pages`: 1이면 이미 불러온 범위(보통 50~75행), 1 늘 때마다 약 50행 더 불러온다.
   - `--dates`: 날짜 구분선을 캡처·OCR해 메시지마다 `date`를 붙인다. 없으면 `date: null`(시간만 있음).
   - `--media`: 사진 메시지를 캡처·OCR한다(글자 없는 사진·이모티콘은 OCR 결과가 비어 있다 — 필요하면 `--media-dir`로 이미지를 남겨 직접 본다).
   - 출력 필드와 추론 규칙(`sender_inferred`, `time_inferred`, `mine`)은 [ax-model.md](references/ax-model.md).
3. **전송**: 확인받은 뒤 `kakaotalk send --room "<방>" --text "<문구>" [--close]`. `status`가 `sent`일 때만 성공으로 보고한다.
4. **예약**: 확인받은 뒤 `kakaotalk schedule add ...` → `schedule list` / `logs <id>` / `remove <id>|--all`.
   옵션·의미론(지각 실행, 1회성 자동 정리, 잠자기)은 [scheduling.md](references/scheduling.md).

```bash
K=<skill-dir>/scripts/kakaotalk
$K schedule add --self --text "점심" --at "2026-11-13 12:00"
$K schedule add --room "<방>" --text "<문구>" --cron "0 9 * * 1-5" --until "2026-12-31 23:59"
$K schedule add --self --text "ping" --every 30m --max-runs 4
$K schedule add ... --dry-run     # 파일·launchd 변경 없이 job·plist만 출력
```

## Failure spec

| 신호 | 의미 | 행동 |
|---|---|---|
| `accessibility-not-trusted` | 실행 주체에 손쉬운 사용 권한 없음 | 터미널(대화형) 또는 바이너리(예약)에 권한 안내 후 기권 |
| `kakaotalk-not-running` / `main-window-not-found` | 앱 미실행·메인 창 없음 | 사용자에게 카카오톡 실행·메인 창 열기 요청 |
| `room-not-found` / `room-ambiguous` | 목록에 정확히 1개로 안 잡힘 | 후보를 보여주고 정확한 이름을 묻는다. 비슷한 방으로 대체 금지 |
| `room-has-unread` | 열면 읽음 처리됨 | 사용자 동의 없이 `--allow-unread` 금지 |
| `other-window-has-draft` / `draft-present` | 쓰다 만 글이 있음 | 건드리지 않고 사용자에게 알린다 |
| `input-mismatch` / `focus-not-on-input` / `window-minimized` | 입력이 의도와 다름 | 입력을 비운 채 실패 보고. `--unminimize`는 사용자 승인 시 |
| `open-failed` | 백그라운드 열기 실패 | `--activate`(카카오톡이 잠깐 앞으로 나옴) 재시도는 사용자에게 알린 뒤 |
| `status: unverified` | 입력은 비었는데 전송 행 미확인 | **자동 재전송 금지**(중복 위험). 방을 다시 읽어 확인 후 보고 |
| `status: not-sent` | 앱이 Enter를 안 받음 | 실패 보고 |
| `status: failed-in-app` / 읽기의 `send_failed: true` | 카카오톡이 전송 실패로 표시(재전송·삭제 버튼) | 자동 재전송 금지. 사용자에게 알리고 앱에서 재전송·삭제를 고르게 한다 |
| `launchd-not-trusted` (`schedule add`) | 바이너리에 손쉬운 사용 권한 없음 — 등록 거부됨 | 권한 추가 안내(`doctor --launchd`의 `hint`) 후 기권 |
| `binary-stale` | 소스가 바이너리보다 새로움 | `build` 후 `doctor --launchd` 재확인 |
| OCR `unparsed` / `non-monotonic` 경고 | 날짜 오인식 | 그 구간 `date`는 null로 두고 경고를 함께 보고. 추측해서 채우지 않는다 |
| 예약 로그 `failed`·`skipped`·`retired: missed-window` | 실행 실패·지각 | 로그 원문을 보여주고 재예약 여부를 묻는다 |

거짓 성공 주의: `AXPress`(전송 버튼)·`AXConfirm`은 성공 코드를 돌려주지만 실제로 전송되지 않는다. 화면에 내 말풍선이
생겨도 카카오톡이 전송에 실패하면 시간 대신 재전송·삭제 버튼이 붙는다(실측). 성공 판정은 CLI의 `status: sent`
(같은 문구의 내 메시지 중 시간 표시가 붙은 행이 늘어남)만 쓴다.

## Termination

- **성공**: `kakaotalk read`는 `ok: true`와 메시지 배열(경고 포함)을 보고. `kakaotalk send`는 `status: sent`. `schedule add`는 `id`와 함께
  `doctor --launchd`의 `trusted: true`가 확인된 상태.
- **기권**: 권한 없음, 방 불명확, 안 읽은 방 동의 없음, 초안 존재 — 아무것도 바꾸지 않고 이유를 보고한다.
- **에스컬레이션**: `unverified` 전송, 예약 실패 로그, 카카오톡 UI 구조 변경(필수 요소 not-found가 반복) — 사용자에게 넘긴다.
- 끝낼 때 이번 작업으로 연 방 창은 `--close`로 닫았는지, 시험용 예약은 `schedule list`에 남지 않았는지 확인한다.

## Commands

```bash
K=<skill-dir>/scripts/kakaotalk
$K doctor [--launchd]        # 환경·권한 진단
$K build [--force]           # swift 소스 → 바이너리 (소스 변경 시에만)
$K rooms                     # 채팅 목록
$K read (--room R|--self) [--pages N] [--dates] [--media] [--media-dir D] [--close] [--allow-unread] [--activate]
$K send (--room R|--self) --text T [--close] [--unminimize] [--allow-unread] [--activate]
$K schedule add (--room R|--self) --text T (--at "Y-m-d H:M"|--every 30m|--cron "m h d M w") [--max-runs N] [--until "Y-m-d H:M"] [--grace 10m] [--dry-run]
$K schedule list | logs <id> | remove <id> | remove --all
$K normalize rows.json       # 오프라인: 저장된 rows 원본 정규화 (eval용)
<skill-dir>/scripts/eval     # 오프라인 eval (카카오톡 불필요)
```
