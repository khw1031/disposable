# TAE 1~4단계와 질문 문구

## 목차

- [출처](#출처)
- [단계 원문과 이 스킬의 질문](#단계-원문과-이-스킬의-질문)
- [맞는 말의 표시](#맞는-말의-표시)
- [출력 형식](#출력-형식)
- [입력→출력 예](#입력출력-예)

## 출처

- TAE 공식 14단계 요약, The International Focusing Institute: https://focusing.org/sites/default/files/upload/2020-06/TAE-steps-short-form.pdf (2026-11-16 앞 네 단계 원문 확인). 문서에 저자 표기는 없다.
- Eugene T. Gendlin, 「Introduction to Thinking at the Edge」, The Folio 19(1), 2004: https://focusing.org/gendlin/docs/gol_2160.html (2026-11-16 원래 주소는 403이라 Wayback 사본 20260222131541로 확인).
- TAE는 Mary Hendricks가 구상하고 만들었고("TAE was envisioned and created by Mary Hendricks."), Gendlin의 이론 구성 수업에서 나왔다("TAE stems from my course called "Theory Construction"").
- 14단계 전체는 경험에서 표현을 찾고, 사례의 관계를 살핀 뒤, 용어를 연결하고 적용을 넓혀 가는 흐름이다. 이 스킬은 표현을 찾는 앞 네 단계만 쓴다. 5단계 이후는 원문을 다시 확인하기 전에는 쓰지 않는다.

## 단계 원문과 이 스킬의 질문

| 단계 | 원문 | 이 스킬의 질문 |
|---|---|---|
| 1 | "A distinct bodily felt sense of something you know" / "A sentence with one main word underlined" / "One instance when it happened" | 「이 문장에서 느낌을 가장 많이 실은 말이 「○○」 맞아요?」 「그 느낌이 실제로 있었던 순간 하나는요?」 |
| 2 | "A not quite logical sentence" | 「앞뒤가 좀 안 맞아도 괜찮으니, 그 느낌을 한 문장으로 말해 보세요.」 |
| 3 | "Reject the public meaning of the underlined word" / "Substitute a second and then a third word, not synonyms" | 「「○○」의 흔한 뜻은 빼고, 동의어 말고 다른 말 두 개를 대 보세요.」 |
| 4 | "What did you want each of the three words to mean? Use fresh phrases" / "What does each word pull out from the felt sense that the others do not?" | 「그 말로 무엇을 말하고 싶었어요? 다른 말에는 없고 그 말에만 있는 건요?」 |

- 2단계의 안 맞는 부분은 고칠 대상이 아니라 단서다. 「조용한데 다 같이 신나는」처럼 부딪히는 두 말이 둘째·셋째 말의 재료가 된다.
- 3단계의 `[AI 후보]`는 사용자의 순간과 문장에 있던 말에서만 뽑는다. 사용자가 말하지 않은 취향(음식 맛, 고급스러움 등)을 끌어오지 않는다. 예외 흐름에서 재료가 원문뿐이면 `[AI 후보 · 흔한 뜻]`으로 적어, 3단계에서 버릴 수 있는 흔한 뜻임을 보인다.
- 4단계 질문은 모든 말에 묻지 않는다. 두 가지로 읽히는 말에만 초안과 같은 턴에 묻는다.

| 상황 | 조립 방법 | 예 |
|---|---|---|
| 순간이 바라던 장면 | 「…같은 곳/것」으로 덧붙인다 | 「작년 송년회 끝나고 간 조용한 술집 같은 곳」 |
| 순간이 잘못된 장면 | 「피하고 싶은 장면」으로 덧붙인다 | 「지난번 임원 보고 때 다들 표에서 길을 잃었다. 그런 일이 없게.」 |
| 밑줄 말 | 사용자가 빼자고 할 때까지 남긴다 | 「깔끔하게」 + 새 조건들 |
| 2단계 문장의 남은 말 | 「아직 말이 안 된 것」에 올린다 | 「꽉 찬」 |

## 맞는 말의 표시

Gendlin 소개문의 문장이다. 「대어 본다」「움직인다」는 이 문장들을 풀어 쓴 이 스킬의 표현이다.

- 말과 느낌은 같지 않다: "An implicitly intricate bodily sense is never the same thing as a statement." (p.1)
- 맞는 말은 느낌에 영향을 준다: "Statements that speak-from the felt sense can be recognized by the fact that they have an effect on the felt sense. It moves, opens, and develops." (p.1)
- 여러 말이 다 안 맞을 때: "When one has tried several words and found that each of them fails to say what needs to be said, fresh sentences can say what one wished the word to mean." (p.3)
- 기권이 실패가 아닌 이유: "…one prefers being stuck and silent until phrases come that do carry the felt sense forward." (p.4)

## 출력 형식

최종본은 아래 순서로 낸다. 비어 있는 절은 뺀다.

```
다듬은 프롬프트
> (보낼 문장)

말의 출처
- 「…」 — 사용자 (원문 또는 몇 번째 답)
- 「…」 — 사용자가 고른 [AI 후보]
- 「…」 — 조립 문구 (조건을 이어 주기만 하는 말)

보내기 전 확인할 빈칸 (TAE 밖, 선택)
- 장소·인원·예산처럼 사실로 정할 것을 질문으로만

아직 말이 안 된 것
- 맞는 말을 못 찾은 느낌
```

## 입력→출력 예

입력: 「회식 장소 알아봐 줘. 분위기 좋은 데로.」

1턴(스킬):
> 밑줄 후보는 「분위기 좋은」이에요. 맞나요? 그리고 두 가지만 알려 주세요. ① 그 느낌이 실제로 있었던 순간 하나 ② 앞뒤가 좀 안 맞아도 되는 문장 하나.

사용자: 「맞아. 작년 송년회 끝나고 간 조용한 술집. 조용한데 다 같이 신나는 곳?」

2턴(스킬):
> 「분위기 좋은」의 흔한 뜻(인테리어, 고급)은 빼고, 동의어가 아닌 다른 말 두 개를 대 보세요. 막히면 방금 말씀에서 뽑은 후보예요: [AI 후보] 「말이 들리는」 「다 같이 앉는」. 고르거나 버리세요.

사용자: 「서로 말이 잘 들리는 곳. 한 테이블.」

3턴(스킬): 초안을 내고 조건을 하나씩 속으로 읽어 보게 한다. 밑줄 말 「분위기 좋은」을 남길지도 묻는다.

사용자: 「둘 다 남겨. 분위기 좋은은 빼도 돼.」

최종:

```
다듬은 프롬프트
> 회식 장소 알아봐 줘. 서로 말이 잘 들릴 만큼 조용하고, 다 같이 한 테이블에 앉을 수 있는 데로. 작년 송년회 끝나고 간 조용한 술집 같은 곳.

말의 출처
- 「서로 말이 잘 들리는」 — 사용자 (2번째 답)
- 「한 테이블」 — 사용자 (2번째 답)
- 「작년 송년회 끝나고 간 조용한 술집」 — 사용자 (1번째 답)
- 「같은 곳」 — 조립 문구
- 「분위기 좋은」을 뺌 — 사용자 (3번째 답)

보내기 전 확인할 빈칸 (TAE 밖, 선택)
- 어느 지역인가요? 몇 명인가요? 1인 예산은요?

아직 말이 안 된 것
- 「다 같이 신나는」 (1번째 답의 문장에서 조건이 되지 않은 말)
```

같은 예에서 피할 출력: 「분위기가 좋고 음식 맛과 서비스도 만족스러운 곳으로, 위치·가격대·메뉴까지 정리해 줘」. 사용자가 하지 않은 「음식 맛과 서비스」가 조건이 되었으므로 거짓 성공이다.
