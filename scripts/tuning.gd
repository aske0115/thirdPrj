# 게임 수치 모음(난이도 담당 파일). 바꾼 뒤엔 봇으로 전후 비교: godot --headless --path . -- --bot --quit-at=125
class_name T

const RUN_SECONDS := 120.0
const WIN_FRACTION := 0.6            # 도시 파괴율이 이만큼이면 바로 승리
const STAR_FRACTIONS := [0.25, 0.4, 0.6]

# 도시
const BLOCK := 3.0                   # 블록 한 변(=한 층) m
const LOT := 22.0                    # 구획 간격 m(건물 + 도로)
const GRID := 5                      # 5x5 구획, 가운데는 광장
const FLOORS_MIN := 3
const FLOORS_MAX := 11
const COLLAPSE_BELOW := 0.25          # 남은 블록이 이 비율 아래면 위층부터 주저앉음
const DROP_COLUMN := 1.0             # 아래가 빈 기둥 블록이 떨어질 확률(0이면 공중에 남음)
const DAMAGE_MUL := 1.0              # 부딪힐 때 부수는 반경 배수
const DEBRIS_CAP := 600

# 쇠공 크기 단계(파괴율 기준)
const STAGE_AT := [0.0, 0.1, 0.28]
const RADIUS := [1.6, 2.5, 3.6]
const MAX_SPEED := [15.0, 18.0, 21.0]
const ACCEL := 30.0
const FRICTION := 0.9                # 초당 감속 비율(입력 없을 때 더 큼)
const IMPACT_MIN_SPEED := 3.0        # 이보다 느리게 닿으면 부수지 못하고 튕김
const IMPACT_SLOW := 0.6             # 부순 뒤 남는 속도 비율
const BOUNCE := 0.35
const CAM_DIST := [1.0, 1.3, 1.7]

# 분노
const RAGE_PER_BLOCK := 0.006
const RAGE_PER_COP := 0.08
const SLAM_RADIUS := 3.2             # 쇠공 반경의 배수

# 체력·경찰
const HP := 100.0
const COP_FIRST := 8.0               # 첫 경찰차 등장 초
const COP_EVERY_START := 6.0
const COP_EVERY_END := 2.5
const COP_MAX := 7
const COP_SPEED := 9.0
const COP_RANGE := 24.0
const COP_SHOOT_EVERY := 1.6
const COP_DAMAGE := 1.2
const PARKED_CARS := 24
