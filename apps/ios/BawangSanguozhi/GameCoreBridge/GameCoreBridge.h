#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface GameCoreBridge : NSObject
- (BOOL)importROMAtPath:(NSString *)source toPath:(NSString *)destination;
- (BOOL)startWithROMPath:(NSString *)romPath sramPath:(NSString *)sramPath;
- (void)setSimplifiedLanguage:(BOOL)enabled;
- (void)stop;
- (nullable NSData *)stepWithButtons:(uint16_t)buttons;
- (nullable NSData *)copyAudio;
- (NSInteger)persistSRAMAtPath:(NSString *)path;
- (nullable NSData *)checkpointData;
- (BOOL)restoreCheckpoint:(NSData *)data;
- (BOOL)forcePersistSRAMAtPath:(NSString *)path;
@property (nonatomic, readonly) uint64_t stateFingerprint;
@property (nonatomic, readonly) NSInteger videoWidth;
@property (nonatomic, readonly) uint64_t nativeInstructionCount;
@property (nonatomic, readonly) uint64_t rawDispatchMissCount;
@property (nonatomic, readonly) uint64_t interpretedInstructionCount;
@end
NS_ASSUME_NONNULL_END
