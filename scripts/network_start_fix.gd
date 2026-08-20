extends "res://scripts/main_network.gd"

# Reliable lobby START: the host starts locally, then tells each connected
# ENet client to start. This avoids the old call_local path on the host.
func _on_lobby_start_pressed() -> void:
    if not lobby_host:
        return
    if player_names.size() < 2:
        if lobby_status_label:
            lobby_status_label.text = "Need at least 2 players (currently %d)" % player_names.size()
        _set_lobby_start_state()
        return

    var selected_mode := match_mode
    var selected_team := team
    var selected_map := map_name

    if lobby_dialog:
        var selects := lobby_dialog.find_children("", "OptionButton", true, false)
        if selects.size() >= 3:
            selected_mode = "team" if selects[0].selected == 1 else "ffa"
            selected_team = ["auto", "red", "blue"][selects[1].selected]
            selected_map = ["construction", "city", "industrial"][selects[2].selected]

    # Close the lobby and start the host immediately.
    _start_match(false)

    # Start every connected client exactly once.
    for client_id in multiplayer.get_peers():
        _remote_start_match.rpc_id(client_id, selected_mode, selected_team, selected_map)
