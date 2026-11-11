// audioprocs.m — 列出当前正在使用音频输入/输出的进程（macOS 14+）
// 编译: clang -fobjc-arc -framework Foundation -framework CoreAudio -o /tmp/audioprocs audioprocs.m
#import <Foundation/Foundation.h>
#include <CoreAudio/CoreAudio.h>
#include <libproc.h>

int main(void) {
    @autoreleasepool {
        AudioObjectPropertyAddress pa = {kAudioHardwarePropertyProcessObjectList,
                                         kAudioObjectPropertyScopeGlobal,
                                         kAudioObjectPropertyElementMain};
        UInt32 size = 0;
        if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &pa, 0, NULL, &size) != noErr) {
            printf("no process object list (older macOS)\n");
            return 1;
        }
        UInt32 n = size / sizeof(AudioObjectID);
        AudioObjectID* objs = malloc(size);
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &pa, 0, NULL, &size, objs);
        printf("共 %u 个音频进程对象\n", n);
        for (UInt32 i = 0; i < n; i++) {
            pid_t pid = 0; UInt32 s = sizeof(pid);
            AudioObjectPropertyAddress a = {kAudioProcessPropertyPID, kAudioObjectPropertyScopeGlobal,
                                            kAudioObjectPropertyElementMain};
            AudioObjectGetPropertyData(objs[i], &a, 0, NULL, &s, &pid);

            UInt32 inRun = 0, outRun = 0;
            AudioObjectPropertyAddress ia = {kAudioProcessPropertyIsRunningInput,
                                             kAudioObjectPropertyScopeGlobal,
                                             kAudioObjectPropertyElementMain};
            AudioObjectPropertyAddress oa = {kAudioProcessPropertyIsRunningOutput,
                                             kAudioObjectPropertyScopeGlobal,
                                             kAudioObjectPropertyElementMain};
            s = sizeof(inRun); AudioObjectGetPropertyData(objs[i], &ia, 0, NULL, &s, &inRun);
            s = sizeof(outRun); AudioObjectGetPropertyData(objs[i], &oa, 0, NULL, &s, &outRun);
            if (!inRun && !outRun) continue;

            char name[PROC_PIDPATHINFO_MAXSIZE] = {0};
            proc_name(pid, name, sizeof(name));
            printf("  pid=%-6d %-28s input=%s output=%s\n", pid, name,
                   inRun ? "YES" : "-", outRun ? "YES" : "-");
        }
        free(objs);
    }
    return 0;
}
