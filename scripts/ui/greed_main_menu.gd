extends "res://scripts/ui/main_menu.gd"


func _open_level_select() -> void:
    audio_manager.play_event(&"ui_click")
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_collection_summary() -> void:
    audio_manager.play_event(&"ui_click")
    progress_label.text = _t("Relic archive and run history are coming next", "遗物档案与挑战记录将在下一阶段扩展")


func _apply_locale() -> void:
    super._apply_locale()
    subtitle_label.text = _t("One arena. Ten waves. Choose every mutation.", "单一竞技场，十轮战斗，选择每一次变异。")
    play_button.text = _t("NEW ARENA RUN", "开始竞技场挑战")
    collection_button.text = _t("RELIC ARCHIVE", "遗物档案")
    progress_label.text = _t("Default mode: autonomous arena and reward choices", "默认模式：全自动竞技场与奖励选择")