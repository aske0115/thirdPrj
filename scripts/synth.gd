# 합성 효과음(직접 만든 소리라 라이선스 걱정 없음).
class_name Synth

static func _wav(samples: PackedFloat32Array, rate := 22050) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w

# 위에서 아래로 떨어지는 짧은 '퓽'
static func zap(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(22050 * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * lerpf(f0, f1, t) / 22050.0
		s[i] = (1.0 if sin(ph) > 0.0 else -1.0) * amp * (1.0 - t) * (1.0 - t)
	return _wav(s)

# 낮게 깔리는 폭발: 걸러 낸 잡음 + 떨어지는 저음
static func noise_boom(dur: float, amp: float) -> AudioStreamWAV:
	var n := int(22050 * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * lerpf(0.5, 0.04, t)
		ph += TAU * lerpf(90.0, 35.0, t) / 22050.0
		var env := pow(1.0 - t, 2.2)
		s[i] = (lp * 1.6 + sin(ph) * 0.8) * amp * env
	return _wav(s)

# 경고음: 두 높이를 번갈아
static func alarm() -> AudioStreamWAV:
	var n := int(22050 * 1.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / 22050.0
		var f := 660.0 if int(t * 5.0) % 2 == 0 else 520.0
		ph += TAU * f / 22050.0
		s[i] = sin(ph) * 0.35 * (1.0 if fmod(t * 5.0, 1.0) < 0.85 else 0.0) * (1.0 - t / 1.2 * 0.5)
	return _wav(s)
