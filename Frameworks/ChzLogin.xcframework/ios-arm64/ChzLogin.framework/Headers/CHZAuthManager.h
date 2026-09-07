#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CHZAuthSuccess)(void);
typedef void (^CHZAuthFailure)(NSString *message);

@interface CHZAuthManager : NSObject

+ (instancetype)sharedManager;
- (void)validateSavedKeyWithSuccess:(CHZAuthSuccess)success failure:(CHZAuthFailure)failure;
- (void)loginWithKey:(NSString *)key success:(CHZAuthSuccess)success failure:(CHZAuthFailure)failure;
- (void)clearSavedKey;

@end

NS_ASSUME_NONNULL_END
