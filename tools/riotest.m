#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <math.h>

static AudioUnit gAU;
static float gPeak = 0;
static long gFrames = 0;

static OSStatus inputCB(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                        UInt32 inNumberFrames, AudioBufferList *ioData) {
    AudioBufferList abl;
    AudioBuffer buf;
    static Float32 data[8192];
    buf.mNumberChannels = 1;
    buf.mDataByteSize = inNumberFrames * sizeof(Float32);
    buf.mData = data;
    abl.mNumberBuffers = 1;
    abl.mBuffers[0] = buf;
    OSStatus st = AudioUnitRender(gAU, ioActionFlags, inTimeStamp, 1, inNumberFrames, &abl);
    if (st == noErr) {
        for (UInt32 i = 0; i < inNumberFrames; i++) {
            float v = fabsf(data[i]);
            if (v > gPeak) gPeak = v;
        }
        gFrames += inNumberFrames;
    }
    return noErr;
}

// Capture via RemoteIO with a specific client format (software SRC)
// args: <sampleRate> <channels>
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        double rate = argc > 1 ? atof(argv[1]) : 44100;
        int channels = argc > 2 ? atoi(argv[2]) : 1;
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_HALOutput;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        if (!comp) { printf("RIO not found\n"); return 1; }
        OSStatus st = AudioComponentInstanceNew(comp, &gAU);
        if (st != noErr) { printf("new failed: %d\n", (int)st); return 1; }
        UInt32 enableInput = 1;
        AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableInput, sizeof(enableInput));
        st = AudioUnitInitialize(gAU);
        if (st != noErr) { printf("RIO INIT FAILED: %d\n", (int)st); return 1; }

        AudioStreamBasicDescription asbd = {0};
        asbd.mSampleRate = rate;
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        asbd.mBytesPerPacket = channels * sizeof(Float32);
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerFrame = channels * sizeof(Float32);
        asbd.mChannelsPerFrame = channels;
        asbd.mBitsPerChannel = 32;
        st = AudioUnitSetProperty(gAU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));
        printf("set client format %.0f Hz %d ch: %d\n", rate, channels, (int)st);

        AURenderCallbackStruct cb;
        cb.inputProc = inputCB;
        cb.inputProcRefCon = NULL;
        st = AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &cb, sizeof(cb));
        if (st != noErr) { printf("callback set failed: %d\n", (int)st); return 1; }
        st = AudioOutputUnitStart(gAU);
        if (st != noErr) { printf("start failed: %d\n", (int)st); return 1; }
        printf("recording 5 seconds at %.0f Hz %d ch... speak now!\n", rate, channels);
        fflush(stdout);
        [NSThread sleepForTimeInterval:5.0];
        AudioOutputUnitStop(gAU);
        AudioUnitUninitialize(gAU);
        AudioComponentInstanceDispose(gAU);
        printf("peak: %.4f frames: %ld (render err frames excluded)\n", gPeak, gFrames);
        printf(gPeak > 0.01 ? "CAPTURE_OK\n" : "CAPTURE_SILENT\n");
    }
    return 0;
}
