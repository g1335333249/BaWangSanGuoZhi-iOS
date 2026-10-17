#import "GameCoreBridge.h"
#include "bawang_core.h"
#include <stdint.h>
#include <stdio.h>

/* Host paths only; ROM conversion and battery file semantics live in C. */
extern "C" const char *exe_relative(const char *name) {
    static char path[2048];
    NSURL *base = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [base URLByAppendingPathComponent:@"BawangSanguozhi" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:folder
                              withIntermediateDirectories:YES attributes:nil error:nil];
    snprintf(path, sizeof path, "%s/%s", folder.fileSystemRepresentation, name);
    return path;
}

@implementation GameCoreBridge {
    uint32_t _pixels[320 * 224];
    BOOL _started;
}

- (BOOL)importROMAtPath:(NSString *)source toPath:(NSString *)destination {
    return bawang_rom_import_file(source.fileSystemRepresentation,
                                  destination.fileSystemRepresentation);
}
- (BOOL)startWithROMPath:(NSString *)romPath sramPath:(NSString *)sramPath {
    if (_started) [self stop];
    _started = bawang_core_start_file(romPath.fileSystemRepresentation,
                                      sramPath.fileSystemRepresentation);
    return _started;
}
- (void)setSimplifiedLanguage:(BOOL)enabled {
    bawang_core_set_simplified(enabled ? 1 : 0);
}
- (void)stop {
    if (_started) bawang_core_stop();
    _started = NO;
}
- (NSData * _Nullable)stepWithButtons:(uint16_t)buttons {
    if (!_started || !bawang_core_frame(buttons, _pixels, 320)) return nil;
    return [NSData dataWithBytes:_pixels length:sizeof _pixels];
}
- (NSInteger)persistSRAMAtPath:(NSString *)path {
    if (!_started) return 0;
    return bawang_core_save_sram_if_changed(path.fileSystemRepresentation);
}
- (NSData * _Nullable)copyAudio {
    if (!_started) return nil;
    int16_t frames[1024 * 2];
    size_t count = bawang_core_audio(frames, 1024);
    return count ? [NSData dataWithBytes:frames length:count * 2 * sizeof(int16_t)] : nil;
}
- (NSData * _Nullable)checkpointData {
    if (!_started) return nil;
    size_t cap = bawang_core_checkpoint_bound();
    if (!cap || cap > 32 * 1024 * 1024) return nil;
    NSMutableData *buffer = [NSMutableData dataWithLength:cap];
    size_t n = bawang_core_checkpoint_save(buffer.mutableBytes, cap);
    if (!n) return nil;
    buffer.length = n;
    return buffer;
}
- (BOOL)restoreCheckpoint:(NSData *)data {
    return _started && bawang_core_checkpoint_load(data.bytes, data.length) != 0;
}
- (BOOL)forcePersistSRAMAtPath:(NSString *)path {
    return _started && bawang_core_save_sram_file(path.fileSystemRepresentation) != 0;
}
- (uint64_t)stateFingerprint { return bawang_core_state_fingerprint(); }
- (NSInteger)videoWidth { return bawang_core_width(); }
- (uint64_t)nativeInstructionCount { return bawang_core_native_instructions(); }
- (uint64_t)rawDispatchMissCount { return bawang_core_raw_dispatch_misses(); }
- (uint64_t)interpretedInstructionCount { return bawang_core_interpreted_instructions(); }
@end
