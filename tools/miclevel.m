// miclevel.m — 录 N 秒默认输入，报 peak / RMS / 是否捕获到声音
// 编译: clang -fobjc-arc -framework Foundation -framework AVFoundation -o /tmp/miclevel miclevel.m
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <math.h>

int main(int argc, char** argv) {
    @autoreleasepool {
        double secs = argc > 1 ? atof(argv[1]) : 4.0;
        AVAudioEngine* eng = [AVAudioEngine new];
        AVAudioInputNode* in = eng.inputNode;
        AVAudioFormat* fmt = [in outputFormatForBus:0];
        printf("DEV: %s | %.0f Hz | %u ch\n",
               eng.inputNode.description ? "default" : "?", fmt.sampleRate,
               (unsigned)fmt.channelCount);
        fflush(stdout);

        __block double peak = 0, sumsq = 0;
        __block long long frames = 0;
        [in installTapOnBus:0 bufferSize:1024 format:fmt
                      block:^(AVAudioPCMBuffer* buf, AVAudioTime* when) {
            float* d = buf.floatChannelData[0];
            for (NSUInteger i = 0; i < buf.frameLength; i++) {
                double v = fabs(d[i]);
                if (v > peak) peak = v;
                sumsq += (double)d[i] * d[i];
                frames++;
            }
        }];
        NSError* err = nil;
        if (![eng startAndReturnError:&err]) {
            printf("ENGINE_START_FAIL: %s\n", err.localizedDescription.UTF8String);
            return 2;
        }
        [NSThread sleepForTimeInterval:secs];
        [eng stop];
        double rms = frames > 0 ? sqrt(sumsq / frames) : 0;
        printf("FRAMES=%lld PEAK=%.5f RMS=%.5f DBFS=%.1f\n", frames, peak, rms,
               rms > 0 ? 20 * log10(rms) : -120.0);
        printf("%s\n", (peak > 0.01 ? "MIC_CAPTURES_AUDIO" : "MIC_SILENT"));
        return peak > 0.01 ? 0 : 1;
    }
}
