# AGENTS.md — 세 번째 게임(thirdPrj) 작업 규칙

> 지금 기획은 **「보스 러시」**(결정 008, `docs/GDD.md`). 아래 「프로젝트 한 줄」의 쇠공은 태그 `wrecker-poc`로 보존된 이전 PoC입니다. 최신 상태는 `docs/HANDOFF.md`.

이 저장소에서 작업하는 사람·AI 에이전트(Claude Code, Codex 등)가 **가장 먼저** 읽는 문서입니다.

> **시작할 때**: `docs/HANDOFF.md`(지금 상태·바로 할 일) → `docs/TODO.md` → `docs/DECISIONS.md` → 최신 `docs/worklogs/` 순서로 읽습니다. 기획은 `docs/GDD.md`, 환경 설치는 `docs/SETUP.md`, 에셋은 `docs/ASSETS.md`.
> **마칠 때**: TODO의 끝난 항목을 ✅로, `docs/worklogs/<날짜>.md`에 기록, `docs/HANDOFF.md` 맨 위 "최신"을 고친 뒤 **커밋·푸시**합니다. 문서만 읽고도 다음 사람이 이어갈 수 있어야 합니다.

## 프로젝트 한 줄
크레인에서 끊어진 철거용 쇠공이 되어 2분 동안 한밤의 정전 도시를 굴러다니며 부수는 모바일 게임. 부술수록 쇠공이 커지고 달아오릅니다. iOS·안드로이드 두 마켓 출시가 목표입니다.

## 기술
- **Godot 4.7.2**(결정 003), 렌더러 `mobile`, 언어 GDScript. 장면은 코드로 짓고(`scripts/main.gd`가 진입점) `.tscn`은 최소로 둡니다.
- 실행·확인 명령은 `docs/SETUP.md`. 봇 자동 플레이·화면 저장: `godot --path . -- --bot --shot=/절대경로.png --shot-at=20 --quit-at=30`.

## 대화·문서 언어
- 사용자와의 대화, 커밋 메시지, 문서, 코드 주석은 **한국어(존댓말)**. 코드 식별자·명령어·경로만 영어.
- 게임 안 문구는 **처음부터 한국어·영어 두 벌**: `Main.L("한국어", "English")`.

## 저장소 규칙
- 원격: `https://github.com/aske0115/thirdPrj`(**공개 저장소**). 작업이 끝날 때마다 한국어 커밋 → `git fetch` → 정상 푸시. **강제 푸시 금지.**
- 커밋 작성자는 개인 계정(`GeunHwa Lee <26166444+aske0115@users.noreply.github.com>`).
- **CC0 에셋과 직접 만든 것만 커밋**합니다(공개 저장소에 올리는 것 자체가 재배포). 유료·재배포 금지 에셋은 커밋하지 않습니다. 받은 곳·라이선스는 `docs/ASSETS.md`.

## 마케팅·문구 원칙
- 스토어·홍보 문구에 경쟁 게임·영화 이름을 쓰지 않습니다. 장르어만 씁니다.
- 홍보 문구에 플레이 시간 숫자를 넣지 않습니다. 홍보는 무료 방법만.

## 역할별 담당 (에이전트 팀)
메인 세션이 PD로서 나눠 맡깁니다. 각 역할은 **아래 자기 담당 파일만** 고치고, 커밋하지 않습니다(PD가 검수 뒤 커밋). 같은 파일을 두 역할이 동시에 고치지 않습니다.

> **화풍 주의(디자인 담당)**: 이 게임은 「한밤의 정전 도시」(블루 아워·남보라 하늘·주황 창문 불빛, 결정 002)입니다. 네온 청록·분홍, 빛 번짐(bloom), 틸트시프트를 쓰지 않습니다. 새 그림은 CC0나 코드(셰이더·입자·절차적 메시)만.

| 역할 | 담당 파일 | 확인 방법 |
|---|---|---|
| 기획 `planner` | `docs/GDD.md`, `docs/DECISIONS.md`, `docs/TODO.md`, `docs/HANDOFF.md`, `docs/worklogs/` | 이전 결정과 충돌 없는지 |
| 난이도 `balance` | `scripts/tuning.gd`(수치 모음) | 봇: `godot --headless --path . -- --bot --quit-at=125`가 찍는 `STATS`·`RESULT` 줄 비교 |
| 디자인 `design` | `shaders/`, `scripts/fx.gd`, `scripts/hud.gd`, `assets/`·`docs/ASSETS.md` | `--shot`으로 화면 저장(창이 잠깐 뜸) |
| 광고 `ads` | (출시 단계에 추가) | — |
| 배포 `release` | `export_presets.cfg`, `ios.sh`, 출시 문서, 개발자 사이트 `~/Projects/daeun-site`의 이 앱 처리방침(그 저장소 AGENTS.md) | `./ios.sh`, `docs/SETUP.md`의 내보내기 명령 |
| 마케팅 `marketing` | (출시 단계에 영상 저장소를 정해 추가) | — |
| 검수 `qa` | 고치지 않음(보고만) | 봇 실행·화면 저장·코드 읽기 |

- `scripts/main.gd`·`city.gd`·`ball.gd`·`cops.gd`(게임 규칙 코드)는 PD가 고치거나 순서를 정해 한 역할에게만 맡깁니다.
- 되돌리기 어려운 일(스토어 제출·콘솔 저장·배포)은 사용자 확인 뒤에만.
