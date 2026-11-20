extends "res://scripts/tests/night2_save_route.gd"
## The same new-game keyboard/physics route and real save-slot checks, without T.
var clock_attempts:=0
func key(code:Key)->void:
	if code==KEY_T:
		clock_attempts+=1;fail("无时钟路线试图使用T");return
	super.key(code)
func finish()->void:
	if clock_attempts>0:fail("时钟使用次数不为0")
	print("DUTY_NO_CLOCK_ATTEMPTS ",clock_attempts)
	await super.finish()
