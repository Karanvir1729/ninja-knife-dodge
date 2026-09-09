/* game_center.h - Game Center leaderboards for Godot 4.7 on iOS.
 * Exposed to GDScript as the "AppleGameCenter" singleton (Engine.get_singleton).
 *   is_available() -> bool          GameKit is present on this build
 *   is_authenticated() -> bool
 *   player_alias() -> String
 *   authenticate()                  emits authenticated(ok, alias, player_id)
 *   report_score(board_id, score)   emits score_reported(board_id, ok, message)
 *   show_leaderboard(board_id)      "" opens the Game Center leaderboards list;
 *                                   emits ui_closed() when the player dismisses it
 */
#ifndef GAME_CENTER_H
#define GAME_CENTER_H

#include "core/object/class_db.h"
#include "core/object/object.h"

class AppleGameCenter : public Object {
	GDCLASS(AppleGameCenter, Object);

	static AppleGameCenter *instance;
	void *delegate = nullptr; // GodotGameCenterDelegate (ObjC), owned here

protected:
	static void _bind_methods();

public:
	static AppleGameCenter *get_singleton();

	bool is_available();
	bool is_authenticated();
	String player_alias();
	void authenticate();
	void report_score(const String &p_leaderboard_id, int p_score);
	void show_leaderboard(const String &p_leaderboard_id);

	// Called back from the ObjC delegate, always on the main thread.
	void authenticated(bool p_ok, const String &p_alias, const String &p_player_id);
	void score_reported(const String &p_leaderboard_id, bool p_ok, const String &p_message);
	void ui_closed();

	AppleGameCenter();
	~AppleGameCenter();
};

#endif // GAME_CENTER_H
