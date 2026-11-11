#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <math.h>

// Test capture at a specific sample rate / channel count (like WeChat uses 16k mono)
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        double rate = argc > 1 ? atof(argv[1]) : 16000;
        int channels = argc > 2 ? atoi(argv[2]) : 1;
        AVAudioEngine *engine = [[AVAudioEngine alloc] init];
        AVAudioInputNode *input = engine.inputNode;
        AVAudioFormat *hwFormat = [input outputFormatForBus:0];
        AVAudioFormat *fmt = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                              sampleRate:rate
                                                                channels:channels
                                                             interleaved:NO];
        printf("hardware: %.0f Hz %u ch | requesting: %.0f Hz %d ch\n",
               hwFormat.sampleRate, (unsigned)hwFormat.channelCount, rate, channels);
        __block float peak = 0;
        __block double sumsq = 0;
        __block long frames = 0;
        [input installTapOnBus:0 bufferSize:4096 format:fmt block:^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
            float *ch = buf.floatChannelData[0];
            long n = (long)buf.frameLength;
            for (long i = 0; i < n; i++) {
                float v = fabsf(ch[i]);
                if (v > peak) peak = v;
                sumsq += (double)v * v;
            }
            frames += n;
        }];
        NSError *err = nil;
        if (![engine startAndReturnError:&err]) {
            printf("ENGINE_ERROR: %s\n", err.localizedDescription.UTF8String);
            return 1;
        }
        printf("recording 5 seconds at %.0f Hz... speak now!\n", rate);
        fflush(stdout);
        [NSThread sleepForTimeInterval:5.0];
        [engine stop];
        [input removeTapOnBus:0];
        double rms = frames > 0 ? sqrt(sumsq / frames) : 0;
        printf("peak: %.4f rms: %.4f frames: %ld\n", peak, rms, frames);
        printf(peak > 0.01 ? "CAPTURE_OK\n" : "CAPTURE_SILENT\n");
    }
    return 0;
}
