# 예약 전송 (launchd)

## 목차

- [구성](#구성)
- [권한](#권한)
- [스케줄 종류](#스케줄-종류)
- [실행 시 판정](#실행-시-판정)
- [확인과 정리](#확인과-정리)

## 구성

`schedule add`가 만드는 것(모두 스킬 디렉토리 밖):

| 파일 | 내용 |
|---|---|
| `~/Library/Application Support/kakaotalk-skill/jobs/<id>.json` | 대상 방·문구·스케줄·제한 (권한 600) |
| `~/Library/Application Support/kakaotalk-skill/jobs/<id>.state.json` | 실행 횟수·마지막 상태 |
| `~/Library/Application Support/kakaotalk-skill/KakaoTalkSkillAX.app` | 바이너리(`Contents/MacOS/kakaotalk-ax`)를 감싼 앱 번들, ad-hoc 서명 |
| `~/Library/LaunchAgents/com.kakaotalk-skill.job.<id>.plist` | 앱 안의 `kakaotalk-ax job <job.json>` 실행 |
| `~/Library/Logs/kakaotalk-skill/<id>.jsonl` | 실행 이벤트(JSON Lines) |

launchd는 Python 래퍼가 아니라 **바이너리를 직접** 실행한다. 판정·전송·정리 로직이 바이너리 안(`job` 명령)에 있는 이유다.

## 권한

- macOS는 launchd가 띄운 프로세스에 터미널의 손쉬운 사용 권한을 물려주지 않는다(실측: 직접 실행·`/bin/sh` 경유 모두
  `trusted=false`, AX 오류 -25211). 셸·파이썬에 권한을 주는 우회는 범위가 너무 넓어 쓰지 않는다.
- `KakaoTalkSkillAX.app`이 손쉬운 사용 목록에 있고 켜져 있어야 한다. 사용자가 설정의 `+`로 추가한다. 앱 번들이 아닌
  명령줄 바이너리는 `+`·끌어다 놓기·권한 요청(`AXIsProcessTrustedWithOptions` prompt) 모두 목록에 들어가지 않았다(실측).
  번들로 감싸 추가한 뒤 launchd 아래 `trusted=true`를 확인했다. `doctor --launchd`가 일회성
  LaunchAgent로 실제 판정하고, `schedule add`도 등록 전에 같은 판정을 돌려 실패하면 `launchd-not-trusted`로 거부한다
  (권한 없이 등록하면 실행 때마다 실패만 기록되는 거짓 성공이 된다).
- 바이너리를 다시 빌드하면(소스 변경) 권한이 풀린다(실측: ad-hoc 서명이라 코드 해시가 바뀜). `build` 후 항상
  `doctor --launchd`로 재확인하고, 풀렸으면 목록에서 `KakaoTalkSkillAX`를 `−`로 지운 뒤 다시 추가해 켠다.
  그래서 CLI는 소스가 바뀌어도 자동 재빌드하지 않고 `binary-stale`로 멈춘다.
- 전송만 하므로 예약 실행에는 화면 기록 권한이 필요 없다.

## 스케줄 종류

| 옵션 | launchd 키 | 비고 |
|---|---|---|
| `--at "YYYY-MM-DD HH:MM"` | `StartCalendarInterval`(월·일·시·분) | 1회성. 연도 키가 없어 매년 반복되므로 실행 후 스스로 plist·job 삭제 + `bootout` |
| `--every 30m` | `StartInterval` | 60초 이상. 첫 실행은 등록 후 한 간격 뒤 |
| `--cron "m h d M w"` | `StartCalendarInterval` 배열 | `*`, 숫자, `a-b`, `a,b`, `*/n`. 200개 항목 초과 시 거부. 요일 0·7=일요일 |

주기형(`--every`, `--cron`)은 `--max-runs` 또는 `--until`이 필수다. `--max-runs`는 성공·실패를 모두 1회로 센다
(실패가 무한 반복되지 않게).

## 실행 시 판정

1. 작업 간 잠금(`jobs/.lock`) — 여러 예약이 동시에 UI를 만지지 않게 한다.
2. `--until` 지남 또는 `max_runs` 도달 → 정리(retired).
3. 지각 판정: 잠자기 중 놓친 달력 예약은 깨어날 때 실행된다. `--at`은 예정 시각보다 `--grace`(기본 10분) 넘게 늦으면
   보내지 않고 정리(`missed-window`). `--cron`은 최근 `--grace` 안에 일치하는 분이 없으면 건너뛴다(`skipped`).
   `--every`는 지각 판정이 없다(깨어나면 한 번 실행).
4. 권한·카카오톡 실행 확인 → 방 열기(백그라운드, `--activate`로 등록했으면 실패 시 앞으로 띄워 재시도) → 전송 →
   결과를 로그에 기록. 재전송하지 않는다.
5. 1회성은 실행 후, 주기형은 마지막 회차 후 스스로 정리한다.

미확인: 화면 잠금·로그아웃 상태에서는 실행되지 않거나 실패할 수 있다. 실패는 로그에 `failed`로 남는다.

## 확인과 정리

```bash
$K schedule list          # jobs + runs/last_status + launchd 로드 여부 + orphan_plists
$K schedule logs <id>     # 이벤트: sent / unverified / not-sent / failed / skipped / retired
$K schedule remove <id>   # bootout + plist·job·state 삭제 (로그는 남김)
$K schedule remove --all
```

시험이 끝나면 `schedule list`의 `jobs`와 `orphan_plists`가 비었는지, `launchctl list | grep kakaotalk-skill`이 비었는지 확인한다.
