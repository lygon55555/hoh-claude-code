# HoH — Claude Code를 위한 Harness-of-Harness

Yan et al., *Harness-of-Harness: Multi-Day Autonomous Software Development with Continual Improvement* ([arXiv:2609.01481](https://arxiv.org/abs/2609.01481))의 Harness-of-Harness 루프를 Claude Code 플러그인으로 구현한 것이다. 역할 에이전트 3종(Planner, Developer, QA), 오케스트레이션 스킬 하나(`/hoh`), 그리고 결정론적인 빌드·테스트 게이트로 구성된다.

특정 프로젝트에 묶이지 않는다. 작은 파일 두 개에 "내 프로젝트를 어떻게 빌드하고 테스트하는지"만 적어 주면 나머지는 루프가 한다.

> English: [README.md](README.md)

## 왜 필요한가

에이전트에게 기능 하나를 맡기면 첫 판은 그럭저럭 괜찮아 보인다. 그런데 "계속해"를 몇 번 누르다 보면 같은 자리를 다시 고치고, 잘 돌던 것을 깨뜨리고, 안 끝난 일을 끝났다고 보고하기 시작한다. **변경을 구현한 주체가 그 변경이 완료됐는지도 판정하기 때문**이다.

HoH는 매 반복을 같은 모델의 독립 호출 3개로 쪼갠다.

| 역할 | 쓸 수 있는 것 | 산출물 |
|---|---|---|
| **Planner** | `plan-<t>.md`, `issues.md` | 이번 반복의 개발 문서: 목표는 최대 3개, 깨지면 안 되는 동작, 그리고 QA가 각각을 어떻게 확인해야 하는지 |
| **Developer** | 코드, 커밋 | 태스크 브랜치에 커밋된 코드 변경 — *동결된 후보(frozen candidate)* |
| **QA** | `evidence-<t>.md`, 로그 | 자기가 직접 관찰한 것에 근거한 주장별 `verified` / `gap` 증거. Developer의 보고서는 절대 보지 않는다 |

반복 사이를 잇는 상태 채널은 둘이다. **코드**(커밋된 산출물)는 다음 Developer로, **증거**는 다음 Planner로 흐른다. 개발 문서는 **넘기지 않는다** — Planner가 매 반복 명세와 최신 증거로부터 새로 쓴다. 논문의 ablation(GameCraft-Bench, Codex + GPT-5.5)에서 개발 문서를 동결하거나, 실행 증거 없이 재계획하거나, 빈 워크스페이스에서 다시 빌드하면 전체 점수가 각각 8.13점, 6.28점, 7.85점 떨어졌다. 이 루프는 셋 다 유지한다.

Developer와 QA 사이에 게이트가 있다. 동결된 커밋을 빌드하고 테스트하는 셸 스크립트로, **모델이 개입하지 않는다**. 커밋 해시와 결과를 기록해 QA에게 넘기고, QA는 그것만을 신뢰할 수 있는 출발점으로 삼는다. 첫 실전 런에서 QA는 이 게이트를 근거로 Developer가 "완료"라고 보고한 회귀를 잡아냈고, 다음 반복이 그것을 되돌렸다.

## 요구 사항

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 2.1 이상 (서브에이전트, 스킬, 플러그인).
- git으로 관리되며, 셸에서 상호작용 없이 빌드·테스트가 되는 프로젝트.
- 예산. 반복 1회는 에이전트 호출 3번 + 전체 빌드·테스트다. T=3이면 1~2시간, 단발 작업의 몇 배 토큰을 잡아야 한다.

Developer 에이전트는 도구 권한이 전부 열려 있다 — 파일을 고치고 셸 명령을 돌리고 커밋한다. **브랜치에서, 리셋해도 되는 리포에서** 돌려라.

## 설치

### 플러그인으로 (권장)

Claude Code 안에서:

```
/plugin marketplace add lygon55555/hoh-claude-code
/plugin install hoh@hoh
```

Claude Code를 재시작한다. 스킬 목록에 `/hoh`가 나타나고, 에이전트는 `hoh:hoh-planner`, `hoh:hoh-developer`, `hoh:hoh-qa`로 보인다.

아무것도 퍼블리시하지 않고 로컬 체크아웃만으로 시험해 보려면:

```bash
git clone https://github.com/lygon55555/hoh-claude-code.git
claude --plugin-dir ./hoh-claude-code
```

### 프로젝트 로컬 (symlink)

플러그인 캐시가 아니라 특정 워크스페이스 안에 하니스를 두고 싶을 때:

```bash
git clone https://github.com/lygon55555/hoh-claude-code.git
./hoh-claude-code/install.sh /path/to/your/workspace --profile node
```

`install.sh`는 `skills/hoh`와 에이전트 3종을 `<workspace>/.claude/`로 symlink하고, 프로파일을 `<workspace>/hoh/`로 복사한다. 다시 실행해도 안전하다.

## 프로젝트 설정

HoH는 워크스페이스에 파일 두 개를 요구한다.

| 파일 | 읽는 주체 | 내용 |
|---|---|---|
| `hoh/project.sh` | 게이트 | `hoh_build()`와 `hoh_test()` — 사람이 직접 타이핑할 그 명령 그대로 |
| `hoh/project.md` | Developer와 QA | 프로젝트 고유 규칙만: 디렉터리 구조, 테스트 하나만 돌리는 방법, 코딩·커밋 규약, 환경의 알려진 특이사항 |

프로파일에서 만들어 놓고 고치면 된다.

```
/hoh init python
```

프로파일: `generic`, `node`, `python`, `go`, `rust`, `xcode`. `generic`을 뺀 나머지는 해당 스택의 기본값을 가정한 **출발점**이다 — 명령이 내 프로젝트에 맞는지 확인해라. `/hoh init`을 다시 실행하면 셀프체크 게이트가 돌고, 두 파일이 제대로 동작하면 `build: ok`가 나온다.

`hoh/project.sh`와 `hoh/project.md`는 **git이 추적하고 있어야 한다** — untracked 상태면 런이 시작을 거부한다. QA가 clean한 트리를 검사하기 때문이다. 커밋해라. 리포에 남기고 싶지 않다면 `.git/info/exclude`에 적어라. `hoh/<task>/` 아래의 런 상태는 반대다 — `/hoh init`이 `.gitignore`에 `hoh/*/`를 추가한다.

전체 계약과 함정(watch 모드, pager, 게이트를 멈춰 세우는 프롬프트)은 [skills/hoh/references/setup.md](skills/hoh/references/setup.md)에 있다.

## 실행

### 1. PRD 작성

**PRD 품질이 루프 전체의 상한선이다.** 먼저 [prd-writing.md](skills/hoh/references/prd-writing.md)를 읽어라. 요약하면:

- **수단이 아니라 목적**을 적어라. 구현 방법을 지정하는 PRD는 자기 자신의 다른 요구사항과 조용히 모순을 일으킨다.
- QA가 **공개 인터페이스를 통해 관찰할 수 있는** 문장으로 써라. "정상 동작한다"가 아니라 "1초 안에 INFO 레벨로 `config reloaded`를 남긴다".
- **자동 검증이 불가능한 것**을 앞에서 선언해라(스크린리더 음성, sudo, 실물 기기). 안 하면 QA가 매 반복 커버리지 갭으로 올린다.
- **범위 밖**이 무엇인지 명시해라.

### 2. 시작

```
/hoh start <task> <path/to/prd.md> [T=3]
```

질문은 딱 한 번 받는다 — 대상 리포지토리, 브랜치 이름, 그리고 프로젝트가 요구한다면 커밋 트레일러. 그 외 모든 결정은 루프가 내리고 로그에 남긴다.

반복 1을 시작하기 전에 `start`는 손대지 않은 트리에서 게이트를 한 번 돌려, 이미 실패하고 있는 것을 전부 `known_fail:`에 기록한다. 루프가 곧바로 시작하지 않는 이유가 이것이고, 런 이전부터 깨져 있던 테스트가 루프가 낸 피해로 읽히지 않게 막아 주는 장치도 이것이다.

빌드할 것이 없는 작업 — 명세 작성, 문서 정리 — 은 `hoh/<task>/config.md`에 `gate: none`을 둘 수 있다. 그러면 기준선 게이트와 매 반복 게이트를 건너뛰고 QA 혼자 판단하게 되는데, 결정론적 확인과 판단이 다시 한 곳에 모인다는 뜻이다. 이 옵션을 고르면 루프가 그 점을 경고한다.

중단된 런을 이어받으려면:

```
/hoh resume <task> [T]
```

### 3. 결과 읽기

전부 `hoh/<task>/`에 떨어진다.

| 파일 | 보는 이유 |
|---|---|
| `log.md` | 반복당 한 줄. 여기서 시작해라 |
| `issues.md` | 누적 원장. **진척은 `qa_status`가 아니라 여기의 open/closed 추세다** |
| `evidence-<t>.md` | QA가 무엇을 어떻게 관찰했고, 어떤 주장이 갭인지 |
| `plan-<t>.md` | 그 반복이 무엇을 하려 했고 왜 그랬는지 |
| `gate-<t>.md` | 게이트 자신의 기록: 후보 커밋, `build:`, `tests:`, 그리고 로그 경로 |
| `logs/build-<t>.log`, `logs/test-<t>.log` | **빌드나 테스트가 왜 실패했는지.** 루프가 반복을 롤백했으면 여기서 시작해라 |
| `lineage.md` | 반복별 커밋, usable/unusable, verified 태그 |

**QA가 `fail`을 돌려주는 것은 정상이다.** 수동 확인만 가능한 항목 하나만 있어도 `pass`가 막힌다. 대신 원장이 줄어드는지를 봐라.

모든 이슈에는 주인이 있다.

| owner | 누가 처리하나 |
|---|---|
| `developer` | 루프가, 다음 반복에서 |
| `orchestrator` | 하니스 문제 — 게이트, 당신의 `project.sh`, 또는 이 리포 |
| `user` | 사람 — 수동 검증, PRD 문구, 환경 |

### 4. 마무리

루프가 만드는 커밋은 WIP다(`chore: [hoh <task>] iter <t> …`). 결과물을 남기려면 squash 해라.

```bash
git reset --soft <t=0 커밋>    # 해시는 lineage.md에 있다
git commit
```

버리려면 브랜치를 지우면 된다. QA를 통과한 반복에는 `hoh/<task>/verified-<t>` 태그가 붙어 있다.

## 반복 한 번은 이렇게 돈다

```
gate-0 = gate.sh(HEAD)                                                      # 기준선: 이미 실패하는 것 -> known_fail

for t in 1..T:
  plan-t      = Planner(prd, evidence-(t-1), issues, lineage, project.md)   # plan-(t-1)은 절대 보지 않는다
  if plan-t.status == complete: break
  candidate-t = Developer(prd, plan-t, project.md)                          # 커밋한다; 트리는 clean이어야 한다
  gate-t      = gate.sh(candidate-t)                                        # 빌드 + 테스트, 모델 없음
  if gate-t.build == fail: evidence-t = 빌드 실패 스텁                       # QA는 아예 호출되지 않는다
  else: evidence-t = QA(prd, plan-t, gate-t, candidate-t)                   # Developer의 보고서는 절대 보지 않는다

  빌드 실패      -> 마지막 usable 커밋으로 리셋
  qa_status pass -> hoh/<task>/verified-t 태그
```

**회귀는 자동으로 롤백되지 않는다.** `regressed`로 등록되고, 빌드 블로커 다음 순위로 다음 반복의 최우선 과제가 된다. 롤백을 유발하는 것은 빌드 실패뿐이다.

## 리포지토리 구조

```
.claude-plugin/          플러그인·마켓플레이스 매니페스트
agents/                  hoh-planner.md, hoh-developer.md, hoh-qa.md
skills/hoh/SKILL.md      /hoh 오케스트레이터
skills/hoh/scripts/      gate.sh
skills/hoh/profiles/     generic, node, python, go, rust, xcode
skills/hoh/references/   setup.md, prd-writing.md
install.sh               프로젝트 로컬 설치 (플러그인의 대안)
```

## 한계

- 무인 다중일 런은 아직 안 된다. 루프는 Claude Code 세션 하나 안에서 T회 반복을 돌고, 세션을 넘어가려면 `/hoh resume`을 쓴다.
- 게이트는 셸로 돌릴 수 있는 것만 확인한다. 시각·청각·권한이 걸린 동작은 사람에게 갭으로 넘어간다.
- watch 모드, 프롬프트, pager에서 멈추는 `project.sh`는 게이트를 정지시킨다. setup.md의 함정 절을 봐라.
- 런 중간에 모델을 바꾸면 기록·보고는 되지만, 논문은 하니스–모델 쌍이 고정된 것을 전제한다. 그런 전환을 끼고 한 비교는 신뢰할 수 없다.
- macOS + Claude Code 2.1에서 테스트했다. 게이트 스크립트는 POSIX 도구와 git만 쓰므로 Linux에서도 돌아야 한다. Windows는 미검증이다.

## 감사의 말

루프, 역할 분리, 2채널 상태 설계는 Yan et al., *Harness-of-Harness: Multi-Day Autonomous Software Development with Continual Improvement*, arXiv:2609.01481 (2026)을 따랐다. 이것은 독립 구현이며 저자들과 제휴 관계가 없다.

## 라이선스

[MIT](LICENSE)
