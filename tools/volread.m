// volread.m — 读取默认输入设备的音量/增益（各元素），可写
// 编译: clang -fobjc-arc -framework Foundation -framework CoreAudio -o /tmp/volread volread.m
#import <Foundation/Foundation.h>
#include <CoreAudio/CoreAudio.h>

static void show(AudioObjectID dev, AudioObjectPropertyScope sc, const char* nm) {
    printf("[%s] ", nm);
    for (UInt32 el = 0; el <= 2; el++) {
        AudioObjectPropertyAddress a = {kAudioDevicePropertyVolumeScalar, sc, el};
        if (!AudioObjectHasProperty(dev, &a)) { printf("el%u:n/a ", el); continue; }
        Float32 v = -1; UInt32 s = sizeof(v);
        OSStatus st = AudioObjectGetPropertyData(dev, &a, 0, NULL, &s, &v);
        if (st != noErr) { printf("el%u:ERR%d ", el, (int)st); continue; }
        Boolean settable = false; UInt32 ss = sizeof(settable);
        AudioObjectIsPropertySettable(dev, &a, &settable);
        printf("el%u:%.2f%s ", el, v, settable ? "(rw)" : "(ro)");
        AudioObjectPropertyAddress d = {kAudioDevicePropertyVolumeDecibels, sc, el};
        if (AudioObjectHasProperty(dev, &d)) {
            Float32 db = -999; UInt32 ds = sizeof(db);
            if (AudioObjectGetPropertyData(dev, &d, 0, NULL, &ds, &db) == noErr)
                printf("[%.1fdB] ", db);
        }
    }
    printf("\n");
}

int main(int argc, char** argv) {
    @autoreleasepool {
        AudioObjectPropertyAddress da = {kAudioHardwarePropertyDefaultInputDevice,
                                         kAudioObjectPropertyScopeGlobal,
                                         kAudioObjectPropertyElementMain};
        AudioObjectID dev = 0; UInt32 sz = sizeof(dev);
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &da, 0, NULL, &sz, &dev);
        printf("input device id=%u\n", (unsigned)dev);
        show(dev, kAudioObjectPropertyScopeInput, "input ");

        AudioObjectPropertyAddress ma = {kAudioDevicePropertyMute, kAudioObjectPropertyScopeInput,
                                         kAudioObjectPropertyElementMain};
        UInt32 mute = 0; UInt32 ms = sizeof(mute);
        if (AudioObjectGetPropertyData(dev, &ma, 0, NULL, &ms, &mute) == noErr)
            printf("input mute=%u\n", (unsigned)mute);

        if (argc > 1) {
            Float32 target = atof(argv[1]);
            for (UInt32 el = 0; el <= 2; el++) {
                AudioObjectPropertyAddress a = {kAudioDevicePropertyVolumeScalar,
                                                kAudioObjectPropertyScopeInput, el};
                if (!AudioObjectHasProperty(dev, &a)) continue;
                Boolean canSet = false; UInt32 cs = sizeof(canSet);
                AudioObjectIsPropertySettable(dev, &a, &canSet);
                if (!canSet) continue;
                OSStatus st = AudioObjectSetPropertyData(dev, &a, 0, NULL, sizeof(target), &target);
                printf("set el%u=%.2f -> %d\n", el, target, (int)st);
            }
        }
    }
    return 0;
}
