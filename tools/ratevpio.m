#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <math.h>

// VPIO capture with arbitrary client sample rate (tests CoreAudio SRC path)
// arg: sample rate (e.g. 24000)
static AudioUnit gAU;
static float gPeak = 0;
static long gFrames = 0;
static double gRunRate = 0;

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
    AudioUnitRender(gAU, ioActionFlags, inTimeStamp, 1, inNumberFrames, &abl);
    for (UInt32 i = 0; i < inNumberFrames; i++) {
        float v = fabsf(data[i]);
        if (v > gPeak) gPeak = v;
    }
    gFrames += inNumberFrames;
    return noErr;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        double rate = argc > 1 ? atof(argv[1]) : 44100;
        gRunRate = rate;
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        if (!comp) { printf("VPIO not found\n"); return 1; }
        OSStatus st = AudioComponentInstanceNew(comp, &gAU);
        if (st != noErr) { printf("new failed: %d\n", (int)st); return 1; }
        UInt32 enableInput = 1, enableOutput = 0;
        AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 0, &enableInput, sizeof(enableInput));
        AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableOutput, sizeof(enableOutput));
        st = AudioUnitInitialize(gAU);
        if (st != noErr) { printf("VPIO INIT FAILED: %d\n", (int)st); return 1; }

        // set client format on output scope of input element (bus 1)
        AudioStreamBasicDescription asbd = {0};
        asbd.mSampleRate = rate;
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        asbd.mBytesPerPacket = sizeof(Float32);
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerFrame = sizeof(Float32);
        asbd.mChannelsPerFrame = 1;
        asbd.mBitsPerChannel = 32;
        st = AudioUnitSetProperty(gAU, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(asbd));
        printf("client format %.0f Hz set: %d\n", rate, (int)st);

        AURenderCallbackStruct cb;
        cb.inputProc = inputCB;
        cb.inputProcRefCon = NULL;
        st = AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &cb, sizeof(cb));
        if (st != noErr) { printf("cb failed: %d\n", (int)st); return 1; }
        AudioOutputUnitStart(gAU);
        printf("recording 5s @ %.0f Hz... speak now!\n", rate);
        fflush(stdout);
        [NSThread sleepForTimeInterval:5.0];
        AudioOutputUnitStop(gAU);
        AudioUnitUninitialize(gAU);
        AudioComponentInstanceDispose(gAU);
        double eff = gFrames / 5.0;
        printf("peak: %.4f frames: %ld (effective %.0f Hz)\n", gPeak, gFrames, eff);
        printf(gPeak > 0.01 ? "CAPTURE_OK\n" : "CAPTURE_SILENT\n");
    }
    return 0;
}
