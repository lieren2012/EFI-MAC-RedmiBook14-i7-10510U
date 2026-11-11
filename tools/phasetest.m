#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <math.h>

typedef struct { float sum, l, r, corr, cancelPeak; } Stats;

int main() {
    @autoreleasepool {
        AVAudioEngine *engine = [[AVAudioEngine alloc] init];
        AVAudioInputNode *input = engine.inputNode;
        AVAudioFormat *format = [input outputFormatForBus:0];
        printf("input: %.0f Hz, %u ch\n", format.sampleRate, (unsigned)format.channelCount);
        __block Stats s1 = {0}, s2 = {0};
        __block long frames = 0;
        [input installTapOnBus:0 bufferSize:4096 format:format block:^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
            float *ch0 = buf.floatChannelData[0];
            float *ch1 = buf.floatChannelData[1];
            long n = (long)buf.frameLength;
            for (long i = 0; i < n; i++) {
                float a = ch0[i], b = ch1[i];
                float sum = a + b;
                float d = fabsf(sum);
                if (d > s1.cancelPeak) s1.cancelPeak = d;
                if (fabsf(a) > s1.l) s1.l = fabsf(a);
                if (fabsf(b) > s1.r) s1.r = fabsf(b);
                if (fabsf(sum) > s1.sum) s1.sum = fabsf(sum);
                s1.corr += a * b;
            }
            frames += n;
        }];
        NSError *err = nil;
        if (![engine startAndReturnError:&err]) { printf("ENGINE_ERROR: %s\n", err.localizedDescription.UTF8String); return 1; }
        printf("recording 8s... SPEAK NOW!\n");
        fflush(stdout);
        [NSThread sleepForTimeInterval:4.0];
        s2 = s1;
        memset(&s1, 0, sizeof(s1));
        [NSThread sleepForTimeInterval:4.0];
        [engine stop];
        [input removeTapOnBus:0];
        printf("window1: L=%.4f R=%.4f | L+R混音=%.4f | 相位相关=%.3f\n", s2.l, s2.r, s2.sum, frames > 0 ? s2.corr / frames : 0);
        printf("window2: L=%.4f R=%.4f | L+R混音=%.4f | 相位相关=%.3f\n", s1.l, s1.r, s1.sum, frames > 0 ? s1.corr / frames : 0);
        float corr = frames > 0 ? s2.corr / frames : 0;
        if (s2.sum < 0.02 && s2.l > 0.05) {
            printf("DIAGNOSIS: 反相抵消! 单声道有信号但 L+R 混音后为静音 → 这就是微信/语音输入静音的原因\n");
        } else if (corr > 0 && s2.sum > 0.02) {
            printf("DIAGNOSIS: 相位正常(相关>0)，L+R 混音有信号，反相理论不成立\n");
        } else {
            printf("DIAGNOSIS: 不确定，corr=%.3f sum=%.4f l=%.4f\n", corr, s2.sum, s2.l);
        }
    }
    return 0;
}
