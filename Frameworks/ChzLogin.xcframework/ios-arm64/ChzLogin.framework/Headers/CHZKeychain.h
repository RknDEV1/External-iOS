#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CHZKeychain : NSObject

+ (BOOL)saveKey:(NSString *)key error:(NSError **)error;
+ (nullable NSString *)loadKey:(NSError **)error;
+ (BOOL)saveSessionForKey:(NSString *)key expiry:(NSString *)expiry error:(NSError **)error;
+ (nullable NSDictionary *)loadSession:(NSError **)error;
+ (BOOL)deleteKey:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
