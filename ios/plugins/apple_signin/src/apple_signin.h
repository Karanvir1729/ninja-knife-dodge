/* apple_signin.h - native Sign in with Apple for Godot 4.7 on iOS.
 * Exposed to GDScript as the "AppleSignIn" singleton (Engine.get_singleton).
 *   is_available() -> bool
 *   sign_in(hashed_nonce: String)      emits sign_in_completed(Dictionary) or sign_in_failed(int, String)
 *   check_credential(user_id: String)  emits credential_state(String)  ("authorized"|"revoked"|"not_found"|"unknown")
 */
#ifndef APPLE_SIGNIN_H
#define APPLE_SIGNIN_H

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/dictionary.h"

class AppleSignIn : public Object {
	GDCLASS(AppleSignIn, Object);

	static AppleSignIn *instance;
	void *delegate = nullptr; // GodotAppleSignInDelegate (ObjC), owned here

protected:
	static void _bind_methods();

public:
	static AppleSignIn *get_singleton();

	bool is_available();
	void sign_in(const String &p_hashed_nonce);
	void check_credential(const String &p_user_id);

	// Called back from the ObjC delegate.
	void completed(const Dictionary &p_result);
	void failed(int p_code, const String &p_message);
	void credential(const String &p_state);

	AppleSignIn();
	~AppleSignIn();
};

#endif // APPLE_SIGNIN_H
