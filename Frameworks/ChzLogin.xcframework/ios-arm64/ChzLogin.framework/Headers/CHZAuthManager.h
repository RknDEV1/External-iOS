#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CHZAuthSuccess)(void);
typedef void (^CHZAuthFailure)(NSString *message);

@interface CHZAuthManager : NSObject

+ (instancetype)sharedManager;
- (BOOL)hasValidSavedSession;
- (void)clearSavedSession;
- (void)loginWithKey:(NSString *)key success:(CHZAuthSuccess)success failure:(CHZAuthFailure)failure;

@end

NS_ASSUME_NONNULL_END
