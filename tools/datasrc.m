// datasrc.m — 读取/切换默认输入设备的 DataSource（内置麦克风 / 线路输入）
// 编译: clang -fobjc-arc -framework Foundation -framework CoreAudio -o /tmp/datasrc datasrc.m
// 用法: ./datasrc          列出可用输入源
//       ./datasrc <序号>   切换到该输入源
#import <Foundation/Foundation.h>
#include <CoreAudio/CoreAudio.h>

static NSString* fourcc(UInt32 v) {
    char c[5] = {(char)(v >> 24), (char)(v >> 16), (char)(v >> 8), (char)v, 0};
    for (int i = 0; i < 4; i++) if (c[i] < 32 || c[i] > 126) c[i] = '.';
    return [NSString stringWithUTF8String:c];
}

int main(int argc, char** argv) {
    @autoreleasepool {
        AudioObjectPropertyAddress da = {kAudioHardwarePropertyDefaultInputDevice,
                                         kAudioObjectPropertyScopeGlobal,
                                         kAudioObjectPropertyElementMain};
        AudioObjectID dev = 0; UInt32 sz = sizeof(dev);
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &da, 0, NULL, &sz, &dev);

        AudioObjectPropertyAddress sa = {kAudioDevicePropertyDataSource,
                                         kAudioObjectPropertyScopeInput,
                                         kAudioObjectPropertyElementMain};
        UInt32 cur = 0; UInt32 cs = sizeof(cur);
        OSStatus st = AudioObjectGetPropertyData(dev, &sa, 0, NULL, &cs, &cur);
        printf("current source: %s (st=%d)\n", fourcc(cur).UTF8String, (int)st);

        AudioObjectPropertyAddress la = {kAudioDevicePropertyDataSources,
                                         kAudioObjectPropertyScopeInput,
                                         kAudioObjectPropertyElementMain};
        UInt32 ls = 0;
        if (AudioObjectGetPropertyDataSize(dev, &la, 0, NULL, &ls) == noErr && ls) {
            UInt32 n = ls / sizeof(UInt32);
            UInt32* list = malloc(ls);
            AudioObjectGetPropertyData(dev, &la, 0, NULL, &ls, list);
            for (UInt32 i = 0; i < n; i++) {
                AudioObjectPropertyAddress na = {kAudioDevicePropertyDataSourceNameForID,
                                                 kAudioObjectPropertyScopeInput, i + 1};
                CFStringRef nm = NULL; UInt32 nsz = sizeof(nm);
                NSString* label = @"";
                AudioObjectPropertyAddress a2 = {kAudioDevicePropertyDataSourceNameForIDCFString,
                                                 kAudioObjectPropertyScopeInput,
                                                 kAudioObjectPropertyElementMain};
                (void)na; (void)label;
                AudioValueTranslation tr = {&list[i], sizeof(UInt32), &nm, sizeof(nm)};
                UInt32 tsz = sizeof(tr);
                if (AudioObjectGetPropertyData(dev, &a2, 0, NULL, &tsz, &tr) == noErr && nm)
                    label = (__bridge_transfer NSString*)nm;
                printf("  [%u] %s  %s%s\n", i + 1, fourcc(list[i]).UTF8String,
                       label.UTF8String, list[i] == cur ? "  <== 当前" : "");
            }
            if (argc > 1) {
                int pick = atoi(argv[1]) - 1;
                if (pick >= 0 && pick < (int)n) {
                    UInt32 v = list[pick];
                    st = AudioObjectSetPropertyData(dev, &sa, 0, NULL, sizeof(v), &v);
                    printf("switch -> %s : %d\n", fourcc(v).UTF8String, (int)st);
                }
            }
            free(list);
        } else {
            printf("no datasources property\n");
        }
    }
    return 0;
}
