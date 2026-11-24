# 개인 프로필 형식

프로필은 스킬 밖 개인 데이터다. `schema_version: 1`, `user_id`, `samples`, `traits`를 가진 JSON을 사용한다. 실제 기록은 빈 배열에서 시작한다.

## 표본

`samples`의 항목은 `id`, `recorded_at`(시간대 포함 ISO 8601), `source_ref`, `context`, `kind`, `text`를 가진다. `kind`는 `user-authored` 또는 `user-roleplay`다. 역할 상황에서 쓴 문장을 실제 생활에서 관찰한 행동으로 바꾸지 않는다.

`context`는 `casual`, `work-peer`, `work-superior`, `unknown` 중 하나다. `unknown`은 저장은 가능하지만 일반적인 말투 규칙의 근거로 사용하지 않는다.

## 특징

`traits`의 항목은 아래 칸을 가진다.

| 칸 | 뜻 |
| --- | --- |
| `id` | 고유한 특징 ID |
| `pattern` | 다음 작성에서 적용할 관찰 가능한 표현 습관 |
| `context` | 해당 습관을 관찰한 상대·상황 |
| `status` | `hypothesis`, `observed`, `confirmed`, `rejected` |
| `evidence` | 실제 표본 ID 배열. 가설도 적어도 하나 필요 |
| `confirmation_ref` | `confirmed`인 경우 사용자가 확인한 실제 대화 위치 |

`observed`는 서로 다른 `source_ref` 두 개 이상에 근거한다. 같은 답을 문장마다 나눠서 근거 개수를 늘리지 않는다. 반말·존댓말과 같은 특징을 다른 맥락에 자동 적용하지 않는다. 사용자 확인만 있고 표본이 없다면 특징을 억지로 만들지 말고, 해당 선호가 드러나는 짧은 문장 하나를 받는다.

이름·연락처를 `user_id`에 넣지 않는다. 기본값은 `default`다. 원문을 가릴 때 `[동료]`, `[회사]`처럼 바꾸고 문장 리듬은 유지한다. 저장은 원자적 교체로 하고 기존 오류 파일을 자동 초기화하지 않는다.
