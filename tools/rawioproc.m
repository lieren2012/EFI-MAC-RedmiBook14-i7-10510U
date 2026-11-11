// rawioproc.m — 直接用 AudioDeviceIOProc 读取默认输入设备的原始数据（绕过 AVAudioEngine）
// 编译: clang -fobjc-arc -framework Foundation -framework CoreAudio -o /tmp/rawioproc rawioproc.m
// 用法: ./rawioproc [秒数]
#import <Foundation/Foundation.h>
#include <CoreAudio/CoreAudio.h>

static double gPeak = 0, gSum = 0;
static long long gFrames = 0;

static OSStatus cb(AudioObjectID dev, const AudioTimeStamp* now, const AudioBufferList* in,
                   const AudioTimeStamp* inTime, AudioBufferList* out, const AudioTimeStamp* outTime,
                   void* ctx) {
    for (UInt32 b = 0; b < in->mNumberBuffers; b++) {
        float* d = (float*)in->mBuffers[b].mData;
        UInt32 n = in->mBuffers[b].mDataByteSize / sizeof(float);
        for (UInt32 i = 0; i < n; i++) {
            double v = d[i] < 0 ? -d[i] : d[i];
            if (v > gPeak) gPeak = v;
            gSum += (double)d[i] * d[i];
            gFrames++;
        }
    }
    return noErr;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        double secs = argc > 1 ? atof(argv[1]) : 4.0;
        AudioObjectPropertyAddress da = {kAudioHardwarePropertyDefaultInputDevice,
                                         kAudioObjectPropertyScopeGlobal,
                                         kAudioObjectPropertyElementMain};
        AudioObjectID dev = 0; UInt32 sz = sizeof(dev);
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &da, 0, NULL, &sz, &dev);
        printf("device id=%u (%s)\n", (unsigned)dev, dev ? "ok" : "NONE");

        AudioDeviceIOProcID proc = NULL;
        OSStatus st = AudioDeviceCreateIOProcID(dev, cb, NULL, &proc);
        printf("createIOProc=%d\n", (int)st);
        if (st != noErr) return 2;
        st = AudioDeviceStart(dev, proc);
        printf("start=%d\n", (int)st);
        if (st != noErr) return 3;
        [NSThread sleepForTimeInterval:secs];
        AudioDeviceStop(dev, proc);
        AudioDeviceDestroyIOProcID(dev, proc);
        double rms = gFrames ? sqrt(gSum / gFrames) : 0;
        printf("FRAMES=%lld PEAK=%.5f RMS=%.5f DBFS=%.1f\n", gFrames, gPeak, rms,
               rms > 0 ? 20 * log10(rms) : -120.0);
        printf("%s\n", gPeak > 0.01 ? "RAW_CAPTURES_AUDIO" : "RAW_SILENT");
        return 0;
    }
}
