#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
#import <stdio.h>

// List available nominal sample rates of default input device, optionally set one: arg "48000"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        AudioDeviceID dev = 0;
        UInt32 size = sizeof(dev);
        AudioObjectPropertyAddress addr = {kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &dev);
        if (!dev) { printf("no input device\n"); return 1; }

        // available rates
        addr.mSelector = kAudioDevicePropertyAvailableNominalSampleRates;
        AudioValueRange ranges[32];
        size = sizeof(ranges);
        UInt32 n = 0;
        if (AudioObjectGetPropertyDataSize(dev, &addr, 0, NULL, &size) == noErr &&
            AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, ranges) == noErr) {
            n = size / sizeof(AudioValueRange);
            printf("available rates:");
            for (UInt32 i = 0; i < n && i < 32; i++) printf(" %.0f-%.0f", ranges[i].mMinimum, ranges[i].mMaximum);
            printf("\n");
        }
        Float64 cur = 0;
        size = sizeof(cur);
        addr.mSelector = kAudioDevicePropertyNominalSampleRate;
        AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, &cur);
        printf("current nominal rate: %.0f\n", cur);

        if (argc > 1) {
            Float64 target = atof(argv[1]);
            // check supported
            int ok = 0;
            for (UInt32 i = 0; i < n && i < 32; i++) if (target >= ranges[i].mMinimum - 1 && target <= ranges[i].mMaximum + 1) ok = 1;
            if (!ok) { printf("rate %.0f not supported\n", target); return 1; }
            OSStatus st = AudioObjectSetPropertyData(dev, &addr, 0, NULL, sizeof(target), &target);
            sleep(1);
            size = sizeof(cur);
            AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, &cur);
            printf("set %.0f: status %d, now %.0f\n", target, (int)st, cur);
        }
    }
    return 0;
}
