extends SceneTree
func _initialize():
    print("class ref: ", AnimatedFighterRig)
    var r = AnimatedFighterRig.new()
    print("instantiated: ", r)
    r.free()
    quit()
