class_name Sprites
## Helpers to build animations from horizontal sprite-sheet strips.

static func frames_from_strip(path: String, frame_count: int, fps: float,
		anim := "default", sf: SpriteFrames = null, loop := true) -> SpriteFrames:
	var tex: Texture2D = load(path)
	var fw := tex.get_width() / frame_count
	var fh := tex.get_height()
	if sf == null:
		sf = SpriteFrames.new()
		sf.remove_animation("default")
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in range(frame_count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, at)
	return sf

static func animated(path: String, frame_count: int, fps: float, autoplay := true) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames_from_strip(path, frame_count, fps)
	if autoplay:
		spr.play("default")
		spr.frame = randi() % frame_count
	return spr
