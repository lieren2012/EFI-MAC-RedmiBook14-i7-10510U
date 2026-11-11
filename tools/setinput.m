#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
#import <stdio.h>

// List input devices; set default input by name substring: arg "USB"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        AudioObjectPropertyAddress addr = {kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
        UInt32 size = 0;
        AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size);
        AudioDeviceID *devs = (AudioDeviceID *)malloc(size);
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, devs);
        int n = (int)(size / sizeof(AudioDeviceID));
        AudioDeviceID usbDev = 0;
        for (int i = 0; i < n; i++) {
            // name
            AudioObjectPropertyAddress na = {kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
            CFStringRef name = NULL;
            UInt32 ns = sizeof(name);
            AudioObjectGetPropertyData(devs[i], &na, 0, NULL, &ns, &name);
            // has input?
            AudioObjectPropertyAddress ia = {kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMain};
            UInt32 isz = 0;
            Boolean hasInput = (AudioObjectGetPropertyDataSize(devs[i], &ia, 0, NULL, &isz) == noErr && isz > 0);
            NSString *nstr = (__bridge_transfer NSString *)name ?: @"?";
            printf("%s [%d] %s\n", nstr.UTF8String, devs[i], hasInput ? "input" : "");
            if (argc > 1 && hasInput && [nstr containsString:@(argv[1])]) usbDev = devs[i];
        }
        if (argc > 1) {
            if (!usbDev) { printf("no matching input device\n"); return 1; }
            AudioObjectPropertyAddress da = {kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
            OSStatus st = AudioObjectSetPropertyData(kAudioObjectSystemObject, &da, 0, NULL, sizeof(usbDev), &usbDev);
            printf("set default input -> %s: %d\n", argv[1], (int)st);
        }
    }
    return 0;
}
