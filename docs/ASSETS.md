# 에셋 목록

모두 **CC0 1.0**(동봉 `License.txt` 원문 확인, 2026-11-17). 공개 저장소에 커밋 가능. 받은 원본 zip은 커밋하지 않고 쓰는 파일만 `assets/`에 둡니다.

| 팩 | 받은 곳 | 저장소 위치 | 쓰는 파일 |
|---|---|---|---|
| Kenney Impact Sounds | https://kenney.nl/assets/impact-sounds | `assets/sfx/` | impactGlass·impactPunch_heavy·impactMining·impactMetal_heavy·footstep_concrete(OGG) |
| Kenney Particle Pack | https://kenney.nl/assets/particle-pack | `assets/fx/` | smoke_04·smoke_07·fire_01·flame_03·spark_04·scorch_02·dirt_02·light_01(PNG 투명) |
| Kenney Smoke Particles | https://kenney.nl/assets/smoke-particles | (라이선스만) | 아직 안 씀 |

- 확인한 내용물: Car Kit에 `police.glb`·`firetruck.glb`·잔해 모델 있음. Impact Sounds에 유리 깨짐 15개(light·medium·heavy). City Kit Roads에 가로등·전신주·표지판·공사 장애물.
- **CC0를 못 찾은 것**: 헬기, 건물 붕괴음(검색된 건 모두 유료), 사이렌 → 코드·합성으로 만듦.
- 받는 법: Kenney 페이지의 Download → "Continue without donating". 버전이 바뀌면 파일 이름을 다시 확인.
- 크기 참고: 경찰차 1.5 × 1.4 × 2.9m(Godot 단위 그대로), 가로등 높이 0.6 → 9배로 키워 씀.

- 2026-11-17 보스 러시로 바꾸며 차·도시 모델(`assets/cars`·`assets/city`)은 뺌(태그 `wrecker-poc`에 남음). 효과음은 합성(`scripts/synth.gd`: 사격·보석·폭발·경보)과 Kenney Impact Sounds를 섞어 씀.
- 후보: Kenney Space Kit(https://kenney.nl/assets/space-kit, CC0 원문 확인, 우주선 craft_speederA~D·포탑 turret_single/double·발전기·구조물 GLTF), Kenney Space Station Kit(CC0 확인), Quaternius Ultimate Spaceships(CC0, glTF, 구글 드라이브).

## 그림 시안(2026-11-17 저녁) 추가
| 팩 | 받은 곳 | 저장소 위치 | 라이선스 원문 | 쓰는 파일 |
|---|---|---|---|---|
| Quaternius Ultimate Spaceships (May 2021) | https://quaternius.com/packs/ultimatespaceships.html → 구글 드라이브 | `assets/ships/` | `License.txt` "CC0 1.0 Universal" | Striker.gltf(내 기체), Executioner.gltf(보스 몸통), 텍스처 내장(기본색). 팩에 11종·색 5종 |
| Kenney Space Kit | https://kenney.nl/assets/space-kit | `assets/kenney-space/` | `License.txt` "Creative Commons Zero, CC0" | turret_double·turret_single·machine_generatorLarge·satelliteDish_detailed(GLB) |
| Black Han Sans | Google Fonts(github.com/google/fonts ofl/blackhansans) | `assets/fonts/` | `OFL-BlackHanSans.txt`(SIL OFL 1.1) | 한글 제목 |
| Orbitron | Google Fonts(ofl/orbitron) | `assets/fonts/` | `OFL-Orbitron.txt`(SIL OFL 1.1) | 숫자·영문 |
- 구글 드라이브 받는 법: 폴더 페이지의 파일 `aria-label`과 `ssk` 속성에서 파일 ID를 뽑아 `https://drive.usercontent.google.com/download?id=<ID>&export=download&confirm=t`.
- OFL 글꼴은 게임에 넣어 배포 가능(글꼴 파일만 따로 팔 수 없음, 라이선스 동봉).

## Poly Pizza의 Quaternius 모델 (CC0, 2026-11-18 추가)
구글 드라이브 공유가 다운로드 한도 초과(Quota exceeded)라, 같은 제작자(Quaternius)가 Poly Pizza에 올린 개별 모델을 받음. 각 페이지에 "By Quaternius", "Public Domain (CC0)" 표기 확인.

| 파일(assets/ships/) | Poly Pizza 페이지 | 쓰는 곳 |
|---|---|---|
| Fighter.glb | https://poly.pizza/m/uCeLfsdmNP | 기체 와이드 |
| Lancer.glb | https://poly.pizza/m/htfBk9vPfw | 기체 랜스 |
| Raider.glb | https://poly.pizza/m/Jqfed124pQ | 기체 헌터 |
| Station.glb | https://poly.pizza/m/aNhGga1jGX | 보스 몸통(고리 정거장) |
| Hauler.glb | https://poly.pizza/m/VSxUAFhzbA | 보스 몸통(화물선) |
| Interceptor.glb | https://poly.pizza/m/PQzePrvBCD | 보스 몸통(대형 전투기) |
| Drone.glb | https://poly.pizza/m/xNbtFQwirO | 졸병 편대 전투기 |
| Scout.glb | https://poly.pizza/m/DbGajMHrvp | 졸병 방패 드론 |
| Mine.glb | https://poly.pizza/m/EC1Lk2IamI | 졸병 기뢰 |

받는 법: 모델 페이지 HTML의 `https://static.poly.pizza/<uuid>.glb` 주소. 미리보기 시트는 `GLTFDocument`로 런타임 로드해 한 장에 렌더.
