#import <Foundation/Foundation.h>
#import <objc/message.h>

static id getManager(void) {
    NSBundle *b = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/SidecarCore.framework"];
    [b load];
    return [NSClassFromString(@"SidecarDisplayManager") sharedManager];
}

static NSArray *allDevices(id mgr) {
    return ((NSArray *(*)(id, SEL))objc_msgSend)(mgr, NSSelectorFromString(@"devices"));
}

static NSArray *connectedDevices(id mgr) {
    return ((NSArray *(*)(id, SEL))objc_msgSend)(mgr, NSSelectorFromString(@"connectedDevices"));
}

static NSString *deviceUUID(id d) {
    id ident = ((id (*)(id, SEL))objc_msgSend)(d, NSSelectorFromString(@"identifier"));
    if ([ident respondsToSelector:@selector(UUIDString)]) {
        return [ident performSelector:@selector(UUIDString)];
    }
    return [ident description] ?: @"unknown";
}

static void printDeviceJSON(NSArray *devices, id mgr) {
    NSMutableArray *arr = [NSMutableArray array];
    NSArray *conn = connectedDevices(mgr);
    for (id d in devices) {
        NSString *name = ((NSString *(*)(id, SEL))objc_msgSend)(d, NSSelectorFromString(@"name"));
        NSString *ident = deviceUUID(d);
        BOOL isConnected = [conn containsObject:d];
        [arr addObject:[NSString stringWithFormat:@"{\"name\":\"%@\",\"id\":\"%@\",\"connected\":%@}",
            name ?: @"unknown", ident ?: @"unknown", isConnected ? @"true" : @"false"]];
    }
    NSString *json = [arr componentsJoinedByString:@","];
    printf("[%s]\n", [json UTF8String]);
}

// CFNotification 回调（C 函数）
static void onDeviceChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    void (^handler)(void) = (__bridge id)observer;
    if (handler) handler();
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        id mgr = getManager();
        NSString *action = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"status";

        // --- list ---
        if ([action isEqualToString:@"list"]) {
            NSArray *devs = allDevices(mgr);
            printDeviceJSON(devs, mgr);
            return 0;
        }

        // --- status ---
        if ([action isEqualToString:@"status"]) {
            NSArray *conn = connectedDevices(mgr);
            printf("%s\n", conn.count ? "CONNECTED" : "DISCONNECTED");
            return 0;
        }

        // --- watch: 监听设备变化事件，输出事件到 stdout ---
        if ([action isEqualToString:@"watch"]) {
            printf("WATCHING\n");
            fflush(stdout);

            __block BOOL keepRunning = YES;

            void (^handler)(void) = ^{
                NSArray *devs = allDevices(mgr);
                printf("EVENT\n");
                printDeviceJSON(devs, mgr);
                fflush(stdout);
            };

            id handlerHolder = [handler copy];

            CFNotificationCenterRef center = CFNotificationCenterGetDistributedCenter();
            CFNotificationCenterAddObserver(center, (__bridge void *)handlerHolder,
                onDeviceChanged,
                CFSTR("SidecarDevicesChangedNotification"), NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(center, (__bridge void *)handlerHolder,
                onDeviceChanged,
                CFSTR("SidecarDisplayManagerConnectedDevicesChangedNotification"), NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately);

            [[NSRunLoop currentRunLoop] run];
            return 0;
        }

        // --- connect / disconnect ---
        NSArray *devs = allDevices(mgr);
        NSString *targetId = argc > 2 ? [NSString stringWithUTF8String:argv[2]] : nil;

        id ipad = nil;
        if (targetId) {
            for (id d in devs) {
                if ([deviceUUID(d) isEqualToString:targetId]) { ipad = d; break; }
            }
        }
        if (!ipad) { ipad = devs.firstObject; }
        if (!ipad) { printf("ERROR: 没有找到设备\n"); return 1; }

        __block dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        void (^completion)(id, NSError *) = ^(id r, NSError *e) {
            dispatch_semaphore_signal(sem);
        };
        id blk = [completion copy];

        SEL sel;
        if ([action isEqualToString:@"connect"]) {
            sel = NSSelectorFromString(@"connectToDevice:completion:");
        } else if ([action isEqualToString:@"disconnect"]) {
            sel = NSSelectorFromString(@"disconnectFromDevice:completion:");
        } else {
            printf("用法: %s [status|connect|disconnect|list|watch] [device-id]\n", argv[0]);
            return 1;
        }

        ((void (*)(id, SEL, id, id))objc_msgSend)(mgr, sel, ipad, blk);
        dispatch_time_t to = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC);
        dispatch_semaphore_wait(sem, to);

        NSArray *conn = connectedDevices(mgr);
        if ([action isEqualToString:@"connect"] && conn.count > 0) {
            NSString *ident = deviceUUID(ipad);
            printf("OK %s\n", [ident UTF8String]);
            return 0;
        } else if ([action isEqualToString:@"disconnect"] && conn.count == 0) {
            printf("OK (已断开)\n"); return 0;
        } else {
            printf("ERROR: 操作可能未完全生效 (已连接设备: %lu)\n", conn.count);
            return 1;
        }
    }
    return 0;
}
