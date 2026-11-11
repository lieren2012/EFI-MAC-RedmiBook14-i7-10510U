#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <math.h>

typedef struct { float v[4]; } Peaks;

int main() {
    @autoreleasepool {
        AVAudioEngine *engine = [[AVAudioEngine alloc] init];
        AVAudioInputNode *input = engine.inputNode;
        AVAudioFormat *format = [input outputFormatForBus:0];
        unsigned chCount = (unsigned)format.channelCount;
        printf("input format: %.0f Hz, %u ch\n", format.sampleRate, chCount);
        __block Peaks p1 = {{0,0,0,0}};
        __block Peaks p2 = {{0,0,0,0}};
        __block long frames = 0;
        [input installTapOnBus:0 bufferSize:4096 format:format block:^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
            long n = (long)buf.frameLength;
            for (unsigned c = 0; c < chCount && c < 4; c++) {
                float *ch = buf.floatChannelData[c];
                for (long i = 0; i < n; i++) {
                    float v = fabsf(ch[i]);
                    if (v > p1.v[c]) p1.v[c] = v;
                }
            }
            frames += n;
        }];
        NSError *err = nil;
        if (![engine startAndReturnError:&err]) {
            printf("ENGINE_ERROR: %s\n", err.localizedDescription.UTF8String);
            return 1;
        }
        printf("recording 8 seconds... speak loudly!\n");
        fflush(stdout);
        [NSThread sleepForTimeInterval:4.0];
        p2 = p1;
        memset(&p1, 0, sizeof(p1));
        [NSThread sleepForTimeInterval:4.0];
        [engine stop];
        [input removeTapOnBus:0];
        printf("window1 (first 4s):");
        for (unsigned c = 0; c < chCount && c < 4; c++) printf(" ch%u=%.4f", c, p2.v[c]);
        printf("\nwindow2 (last 4s):");
        for (unsigned c = 0; c < chCount && c < 4; c++) printf(" ch%u=%.4f", c, p1.v[c]);
        printf("\nframes: %ld\n", frames);
        float best = 0;
        for (unsigned c = 0; c < chCount && c < 4; c++) { if (p1.v[c] > best) best = p1.v[c]; if (p2.v[c] > best) best = p2.v[c]; }
        printf(best > 0.01 ? "MIC_OK (best=%.4f)\n" : "MIC_WEAK_SILENT (best=%.4f)\n", best);
    }
    return 0;
}
