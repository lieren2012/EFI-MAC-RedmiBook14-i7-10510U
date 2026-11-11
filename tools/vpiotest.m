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
    AudioUnitRender(gAU, ioActionFlags, inTimeStamp, 1, inNumberFrames, &abl);
    for (UInt32 i = 0; i < inNumberFrames; i++) {
        float v = fabsf(data[i]);
        if (v > gPeak) gPeak = v;
    }
    gFrames += inNumberFrames;
    return noErr;
}

// Capture via VoiceProcessingIO (echo-cancel unit, used by WeChat/QQ/Zoom)
int main() {
    @autoreleasepool {
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        if (!comp) { printf("VPIO component not found\n"); return 1; }
        OSStatus st = AudioComponentInstanceNew(comp, &gAU);
        if (st != noErr) { printf("new failed: %d\n", (int)st); return 1; }
        UInt32 enableInput = 1, enableOutput = 0;
        AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 0, &enableInput, sizeof(enableInput));
        AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enableOutput, sizeof(enableOutput));
        st = AudioUnitInitialize(gAU);
        if (st != noErr) { printf("VPIO INIT FAILED: %d\n", (int)st); return 1; }
        printf("VPIO initialized OK\n");

        AURenderCallbackStruct cb;
        cb.inputProc = inputCB;
        cb.inputProcRefCon = NULL;
        st = AudioUnitSetProperty(gAU, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &cb, sizeof(cb));
        if (st != noErr) { printf("callback set failed: %d\n", (int)st); return 1; }
        AudioOutputUnitStart(gAU);
        printf("recording 5 seconds via VPIO... speak now!\n");
        fflush(stdout);
        [NSThread sleepForTimeInterval:5.0];
        AudioOutputUnitStop(gAU);
        AudioUnitUninitialize(gAU);
        AudioComponentInstanceDispose(gAU);
        printf("peak: %.4f frames: %ld\n", gPeak, gFrames);
        printf(gPeak > 0.01 ? "VPIO_CAPTURE_OK\n" : "VPIO_CAPTURE_SILENT\n");
    }
    return 0;
}
