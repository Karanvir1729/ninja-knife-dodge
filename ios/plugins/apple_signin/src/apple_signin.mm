/* apple_signin.mm - see apple_signin.h. Built by tools/build_ios_plugin.sh against the
 * Godot 4.7.2 source tree; the static library is linked into the exported Xcode project
 * through ios/plugins/apple_signin.gdip. */
#include "apple_signin.h"

#include "core/config/engine.h"
#include "core/string/ustring.h"

#import <AuthenticationServices/AuthenticationServices.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static String ns_to_godot(NSString *s) {
	if (s == nil) {
		return String();
	}
	return String::utf8([s UTF8String]);
}

@interface GodotAppleSignInDelegate : NSObject <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>
@property(nonatomic, assign) AppleSignIn *owner;
@property(nonatomic, strong) ASAuthorizationController *controller;
@end

@implementation GodotAppleSignInDelegate

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller {
	UIWindow *key = nil;
	for (UIWindow *w in [UIApplication sharedApplication].windows) {
		if (w.isKeyWindow) {
			key = w;
			break;
		}
	}
	if (key == nil && [UIApplication sharedApplication].windows.count > 0) {
		key = [UIApplication sharedApplication].windows.firstObject;
	}
	return key;
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization {
	if (![authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
		if (self.owner) {
			self.owner->failed(-1, "Unexpected credential type");
		}
		return;
	}
	ASAuthorizationAppleIDCredential *cred = (ASAuthorizationAppleIDCredential *)authorization.credential;
	Dictionary result;
	result["user"] = ns_to_godot(cred.user);
	result["email"] = ns_to_godot(cred.email);
	result["given_name"] = ns_to_godot(cred.fullName.givenName);
	result["family_name"] = ns_to_godot(cred.fullName.familyName);
	NSString *token = cred.identityToken ? [[NSString alloc] initWithData:cred.identityToken encoding:NSUTF8StringEncoding] : nil;
	NSString *code = cred.authorizationCode ? [[NSString alloc] initWithData:cred.authorizationCode encoding:NSUTF8StringEncoding] : nil;
	result["identity_token"] = ns_to_godot(token);
	result["authorization_code"] = ns_to_godot(code);
	result["real_user_status"] = (int)cred.realUserStatus;
	if (self.owner) {
		self.owner->completed(result);
	}
	self.controller = nil;
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error {
	if (self.owner) {
		self.owner->failed((int)error.code, ns_to_godot(error.localizedDescription));
	}
	self.controller = nil;
}

@end

AppleSignIn *AppleSignIn::instance = nullptr;

AppleSignIn *AppleSignIn::get_singleton() {
	return instance;
}

void AppleSignIn::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &AppleSignIn::is_available);
	ClassDB::bind_method(D_METHOD("sign_in", "hashed_nonce"), &AppleSignIn::sign_in);
	ClassDB::bind_method(D_METHOD("check_credential", "user_id"), &AppleSignIn::check_credential);
	ADD_SIGNAL(MethodInfo("sign_in_completed", PropertyInfo(Variant::DICTIONARY, "result")));
	ADD_SIGNAL(MethodInfo("sign_in_failed", PropertyInfo(Variant::INT, "code"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("credential_state", PropertyInfo(Variant::STRING, "state")));
}

bool AppleSignIn::is_available() {
	if (@available(iOS 13.0, *)) {
		return true;
	}
	return false;
}

void AppleSignIn::sign_in(const String &p_hashed_nonce) {
	if (@available(iOS 13.0, *)) {
		GodotAppleSignInDelegate *d = (__bridge GodotAppleSignInDelegate *)delegate;
		ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
		ASAuthorizationAppleIDRequest *request = [provider createRequest];
		request.requestedScopes = @[ ASAuthorizationScopeFullName, ASAuthorizationScopeEmail ];
		if (!p_hashed_nonce.is_empty()) {
			request.nonce = [NSString stringWithUTF8String:p_hashed_nonce.utf8().get_data()];
		}
		ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ request ]];
		controller.delegate = d;
		controller.presentationContextProvider = d;
		d.controller = controller;
		[controller performRequests];
	} else {
		failed(-2, "Sign in with Apple needs iOS 13");
	}
}

void AppleSignIn::check_credential(const String &p_user_id) {
	if (@available(iOS 13.0, *)) {
		ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
		NSString *uid = [NSString stringWithUTF8String:p_user_id.utf8().get_data()];
		[provider getCredentialStateForUserID:uid
								   completion:^(ASAuthorizationAppleIDProviderCredentialState state, NSError *_Nullable error) {
									   String s = "unknown";
									   switch (state) {
										   case ASAuthorizationAppleIDProviderCredentialAuthorized:
											   s = "authorized";
											   break;
										   case ASAuthorizationAppleIDProviderCredentialRevoked:
											   s = "revoked";
											   break;
										   case ASAuthorizationAppleIDProviderCredentialNotFound:
											   s = "not_found";
											   break;
										   default:
											   break;
									   }
									   dispatch_async(dispatch_get_main_queue(), ^{
										   if (AppleSignIn::get_singleton()) {
											   AppleSignIn::get_singleton()->credential(s);
										   }
									   });
								   }];
	} else {
		credential("unknown");
	}
}

void AppleSignIn::completed(const Dictionary &p_result) {
	emit_signal("sign_in_completed", p_result);
}

void AppleSignIn::failed(int p_code, const String &p_message) {
	emit_signal("sign_in_failed", p_code, p_message);
}

void AppleSignIn::credential(const String &p_state) {
	emit_signal("credential_state", p_state);
}

AppleSignIn::AppleSignIn() {
	ERR_FAIL_COND(instance != nullptr);
	instance = this;
	GodotAppleSignInDelegate *d = [[GodotAppleSignInDelegate alloc] init];
	d.owner = this;
	delegate = (__bridge_retained void *)d;
}

AppleSignIn::~AppleSignIn() {
	if (delegate) {
		GodotAppleSignInDelegate *d = (__bridge_transfer GodotAppleSignInDelegate *)delegate;
		d.owner = nullptr;
		delegate = nullptr;
	}
	instance = nullptr;
}

// Entry points named in apple_signin.gdip; the export writes calls to them into the app.
static AppleSignIn *apple_signin_plugin = nullptr;

void apple_signin_init() {
	apple_signin_plugin = memnew(AppleSignIn);
	Engine::get_singleton()->add_singleton(Engine::Singleton("AppleSignIn", apple_signin_plugin));
}

void apple_signin_deinit() {
	if (apple_signin_plugin) {
		memdelete(apple_signin_plugin);
		apple_signin_plugin = nullptr;
	}
}
