#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CHZKeychain : NSObject

+ (BOOL)saveKey:(NSString *)key error:(NSError **)error;
+ (nullable NSString *)loadKey:(NSError **)error;
+ (BOOL)deleteKey:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
