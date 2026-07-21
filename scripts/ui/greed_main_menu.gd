extends "res://scripts/ui/main_menu.gd"


func _open_level_select() -> void:
    audio_manager.play_event(&"ui_click")
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_collection_summary() -> void:
    audio_manager.play_event(&"ui_click")
    progress_label.text = _t("Plant archive, weapon evolutions, and run history are coming next", "植物图鉴、武器进化与生存记录将在下一阶段扩展")


func _apply_locale() -> void:
    super._apply_locale()
    subtitle_label.text = _t("Move, survive, collect dew, and grow an unstoppable garden.", "移动、生存、收集露珠，培育势不可挡的花园。")
    play_button.text = _t("START SURVIVAL RUN", "开始生存挑战")
    collection_button.text = _t("PLANT ARCHIVE", "植物图鉴")
    progress_label.text = _t("Default mode: 90-second plant survivors prototype", "默认模式：90 秒植物幸存者原型")
