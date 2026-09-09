/* game_center.mm - see game_center.h. Built by tools/build_ios_plugin.sh against
 * the Godot 4.7.2 source tree; the static library is linked into the exported
 * Xcode project through ios/plugins/game_center.gdip. */
// GameKit drags in GameController, whose GCPhysicalInputElementCollection<Key:...>
// generic collides with Godot's global `enum class Key`. Importing the system
// frameworks before any engine header keeps that name out of scope while they parse.
#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>

#include "game_center.h"

#include "core/config/engine.h"
#include "core/string/ustring.h"

static String ns_to_godot(NSString *s) {
	if (s == nil) {
		return String();
	}
	return String::utf8([s UTF8String]);
}

static NSString *godot_to_ns(const String &s) {
	return [NSString stringWithUTF8String:s.utf8().get_data()];
}

/* The view controller a modal should be presented from. Found the way Apple's
 * own GameKit wrapper finds it - through the connected scenes, not the
 * long-deprecated keyWindow - then walking past whatever it already presents. */
static UIViewController *top_view_controller() {
	UIWindow *window = nil;
	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		for (UIWindow *w in ((UIWindowScene *)scene).windows) {
			if (w.isKeyWindow && w.rootViewController != nil) {
				window = w;
				break;
			}
			if (window == nil && w.rootViewController != nil) {
				window = w;
			}
		}
		if (window != nil && window.isKeyWindow) {
			break;
		}
	}
	UIViewController *vc = window.rootViewController;
	while (vc.presentedViewController != nil) {
		vc = vc.presentedViewController;
	}
	return vc;
}

@interface GodotGameCenterDelegate : NSObject <GKGameCenterControllerDelegate>
@property(nonatomic, assign) AppleGameCenter *owner;
@end

@implementation GodotGameCenterDelegate

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController {
	[gameCenterViewController dismissViewControllerAnimated:YES
												 completion:^{
													 if (self.owner) {
														 self.owner->ui_closed();
													 }
												 }];
}

@end

AppleGameCenter *AppleGameCenter::instance = nullptr;

AppleGameCenter *AppleGameCenter::get_singleton() {
	return instance;
}

void AppleGameCenter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &AppleGameCenter::is_available);
	ClassDB::bind_method(D_METHOD("is_authenticated"), &AppleGameCenter::is_authenticated);
	ClassDB::bind_method(D_METHOD("player_alias"), &AppleGameCenter::player_alias);
	ClassDB::bind_method(D_METHOD("authenticate"), &AppleGameCenter::authenticate);
	ClassDB::bind_method(D_METHOD("report_score", "leaderboard_id", "score"), &AppleGameCenter::report_score);
	ClassDB::bind_method(D_METHOD("show_leaderboard", "leaderboard_id"), &AppleGameCenter::show_leaderboard);
	ADD_SIGNAL(MethodInfo("authenticated", PropertyInfo(Variant::BOOL, "ok"), PropertyInfo(Variant::STRING, "alias"), PropertyInfo(Variant::STRING, "player_id")));
	ADD_SIGNAL(MethodInfo("score_reported", PropertyInfo(Variant::STRING, "leaderboard_id"), PropertyInfo(Variant::BOOL, "ok"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("ui_closed"));
}

bool AppleGameCenter::is_available() {
	return true;
}

bool AppleGameCenter::is_authenticated() {
	return [GKLocalPlayer localPlayer].isAuthenticated == YES;
}

String AppleGameCenter::player_alias() {
	GKLocalPlayer *p = [GKLocalPlayer localPlayer];
	if (!p.isAuthenticated) {
		return String();
	}
	return ns_to_godot(p.alias);
}

/* Sets the authenticate handler. GameKit allows this only once per process, so
 * a second call just replays the state we already have. GameKit itself calls
 * the handler again later (when the player signs in from Settings, say), so the
 * signal is the current state rather than a one-shot event. */
void AppleGameCenter::authenticate() {
	GKLocalPlayer *player = [GKLocalPlayer localPlayer];
	if (player.authenticateHandler != nil) {
		if (player.isAuthenticated) {
			authenticated(true, ns_to_godot(player.alias), ns_to_godot(player.gamePlayerID));
		} else {
			authenticated(false, String(), String());
		}
		return;
	}
	player.authenticateHandler = ^(UIViewController *view_controller, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			AppleGameCenter *self_ptr = AppleGameCenter::get_singleton();
			if (self_ptr == nullptr) {
				return;
			}
			if (view_controller != nil) {
				UIViewController *top = top_view_controller();
				if (top != nil) {
					[top presentViewController:view_controller animated:YES completion:nil];
				}
				return;
			}
			GKLocalPlayer *p = [GKLocalPlayer localPlayer];
			if (p.isAuthenticated) {
				self_ptr->authenticated(true, ns_to_godot(p.alias), ns_to_godot(p.gamePlayerID));
			} else {
				self_ptr->authenticated(false, String(), String());
			}
		});
	};
}

void AppleGameCenter::report_score(const String &p_leaderboard_id, int p_score) {
	if (![GKLocalPlayer localPlayer].isAuthenticated) {
		score_reported(p_leaderboard_id, false, "not signed in to Game Center");
		return;
	}
	String board = p_leaderboard_id;
	NSString *board_ns = godot_to_ns(board);
	[GKLeaderboard submitScore:(NSInteger)p_score
					   context:0
						player:[GKLocalPlayer localPlayer]
				leaderboardIDs:@[ board_ns ]
			 completionHandler:^(NSError *_Nullable error) {
				 String message = error == nil ? String() : ns_to_godot(error.localizedDescription);
				 bool ok = error == nil;
				 dispatch_async(dispatch_get_main_queue(), ^{
					 if (AppleGameCenter::get_singleton()) {
						 AppleGameCenter::get_singleton()->score_reported(board, ok, message);
					 }
				 });
			 }];
}

void AppleGameCenter::show_leaderboard(const String &p_leaderboard_id) {
	GodotGameCenterDelegate *d = (__bridge GodotGameCenterDelegate *)delegate;
	GKGameCenterViewController *vc = nil;
	if (p_leaderboard_id.is_empty()) {
		vc = [[GKGameCenterViewController alloc] initWithState:GKGameCenterViewControllerStateLeaderboards];
	} else {
		vc = [[GKGameCenterViewController alloc] initWithLeaderboardID:godot_to_ns(p_leaderboard_id)
														  playerScope:GKLeaderboardPlayerScopeGlobal
														   timeScope:GKLeaderboardTimeScopeAllTime];
	}
	vc.gameCenterDelegate = d;
	UIViewController *top = top_view_controller();
	if (top == nil) {
		ui_closed();
		return;
	}
	[top presentViewController:vc animated:YES completion:nil];
}

void AppleGameCenter::authenticated(bool p_ok, const String &p_alias, const String &p_player_id) {
	emit_signal("authenticated", p_ok, p_alias, p_player_id);
}

void AppleGameCenter::score_reported(const String &p_leaderboard_id, bool p_ok, const String &p_message) {
	emit_signal("score_reported", p_leaderboard_id, p_ok, p_message);
}

void AppleGameCenter::ui_closed() {
	emit_signal("ui_closed");
}

AppleGameCenter::AppleGameCenter() {
	ERR_FAIL_COND(instance != nullptr);
	instance = this;
	GodotGameCenterDelegate *d = [[GodotGameCenterDelegate alloc] init];
	d.owner = this;
	delegate = (__bridge_retained void *)d;
}

AppleGameCenter::~AppleGameCenter() {
	if (delegate) {
		GodotGameCenterDelegate *d = (__bridge_transfer GodotGameCenterDelegate *)delegate;
		d.owner = nullptr;
		delegate = nullptr;
	}
	instance = nullptr;
}

// Entry points named in game_center.gdip; the export writes calls to them into the app.
static AppleGameCenter *game_center_plugin = nullptr;

void game_center_init() {
	game_center_plugin = memnew(AppleGameCenter);
	Engine::get_singleton()->add_singleton(Engine::Singleton("AppleGameCenter", game_center_plugin));
}

void game_center_deinit() {
	if (game_center_plugin) {
		memdelete(game_center_plugin);
		game_center_plugin = nullptr;
	}
}
