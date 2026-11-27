/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at https://mozilla.org/MPL/2.0/.
 */

// Adjust the selected CoreAudio output device buffer during Wine initialization.
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>
#include <stdbool.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static OSStatus initialize_output(AudioUnit unit)
{
    const char *mode = getenv("FNAF4_AUDIO_BUFFER");
    if (!mode) {
        return AudioUnitInitialize(unit);
    }

    UInt32 output_enabled = 0;
    UInt32 size = sizeof output_enabled;
    if (AudioUnitGetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output, 0, &output_enabled, &size) != noErr ||
        !output_enabled) {
        return AudioUnitInitialize(unit);
    }

    AudioDeviceID device = kAudioObjectUnknown;
    size = sizeof device;
    if (AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global, 0, &device, &size) != noErr) {
        return AudioUnitInitialize(unit);
    }

    const AudioObjectPropertyAddress rate = {
        kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain,
    };
    const AudioObjectPropertyAddress buffer = {
        kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain,
    };
    Float64 sample_rate = 0;
    size = sizeof sample_rate;
    if (AudioObjectGetPropertyData(device, &rate, 0, NULL, &size, &sample_rate) != noErr) {
        return AudioUnitInitialize(unit);
    }
    UInt32 previous = 0;
    size = sizeof previous;
    if (AudioObjectGetPropertyData(device, &buffer, 0, NULL, &size, &previous) != noErr ||
        sample_rate <= 0 || sample_rate > 384000) {
        return AudioUnitInitialize(unit);
    }

    const UInt32 target = (UInt32)(sample_rate * (256.0 / 48000.0));
    const bool adjust = (strcmp(mode, "short") == 0 || strcmp(mode, "aligned") == 0) &&
                        target < previous;
    OSStatus changed = noErr;
    if (adjust) {
        changed = AudioObjectSetPropertyData(device, &buffer, 0, NULL, sizeof target, &target);
    }
    const OSStatus initialized = AudioUnitInitialize(unit);
    UInt32 now = 0;
    size = sizeof now;
    const OSStatus readback = AudioObjectGetPropertyData(device, &buffer, 0, NULL, &size, &now);
    fprintf(stderr, "FNAF4 audio: %.0f Hz, buffer %u -> %u frames, adjust=%d, set=%d, read=%d, init=%d\n",
            sample_rate, previous, now, adjust, (int)changed, (int)readback, (int)initialized);
    AudioStreamBasicDescription stream = {0};
    size = sizeof stream;
    if (AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                             0, &stream, &size) == noErr) {
        fprintf(stderr, "FNAF4 audio: playback stream %.0f Hz, %u channels\n",
                stream.mSampleRate, stream.mChannelsPerFrame);
    }
    return initialized;
}

__attribute__((used, section("__DATA,__interpose")))
static const struct {
    OSStatus (*replacement)(AudioUnit);
    OSStatus (*original)(AudioUnit);
} audio_unit_hook = { initialize_output, AudioUnitInitialize };

// Report a 44.1 kHz mix rate only to Wine's driver. CoreAudio still converts to
// the physical device rate, and other clients keep their own device settings.
static OSStatus report_mix_rate(AudioObjectID device, const AudioObjectPropertyAddress *address,
                                UInt32 qualifier_size, const void *qualifier,
                                UInt32 *size, void *data)
{
    const OSStatus result = AudioObjectGetPropertyData(device, address, qualifier_size,
                                                       qualifier, size, data);
    if (result != noErr || !address || address->mSelector != kAudioDevicePropertyNominalSampleRate ||
        !size || *size != sizeof(Float64) || !data) {
        return result;
    }
    const char *mode = getenv("FNAF4_AUDIO_BUFFER");
    if (!mode || strcmp(mode, "aligned") != 0) {
        return result;
    }
    Dl_info caller;
    if (dladdr(__builtin_return_address(0), &caller) && caller.dli_fname &&
        strstr(caller.dli_fname, "/winecoreaudio.so") && *(Float64 *)data == 48000.0) {
        *(Float64 *)data = 44100.0;
    }
    return result;
}

__attribute__((used, section("__DATA,__interpose")))
static const struct {
    typeof(&AudioObjectGetPropertyData) replacement;
    typeof(&AudioObjectGetPropertyData) original;
} audio_rate_hook = { report_mix_rate, AudioObjectGetPropertyData };
