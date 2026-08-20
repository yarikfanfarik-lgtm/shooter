extends Node

var sensitivity := 1.0
var fov := 90.0
var graphics := 1
var player_name := ""
var mobile_layout := {
    "fire": {"x": 0.86, "y": 0.78, "size": 96.0},
    "jump": {"x": 0.78, "y": 0.68, "size": 76.0},
    "reload": {"x": 0.70, "y": 0.82, "size": 70.0},
    "weapon": {"x": 0.90, "y": 0.55, "size": 70.0}
}

func _ready() -> void:
    load_settings()

func save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("controls", "sensitivity", sensitivity)
    cfg.set_value("video", "fov", fov)
    cfg.set_value("video", "graphics", graphics)
    cfg.set_value("profile", "player_name", player_name)
    cfg.set_value("mobile", "layout", mobile_layout)
    cfg.save("user://settings.cfg")

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://settings.cfg") != OK:
        return
    sensitivity = float(cfg.get_value("controls", "sensitivity", sensitivity))
    fov = float(cfg.get_value("video", "fov", fov))
    graphics = int(cfg.get_value("video", "graphics", graphics))
    player_name = str(cfg.get_value("profile", "player_name", player_name)).strip_edges()
    mobile_layout = cfg.get_value("mobile", "layout", mobile_layout)
