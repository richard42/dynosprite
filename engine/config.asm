*********************************************************************************
* DynoSprite - config.asm
* Copyright (c) 2014, Richard Goedeken
* All rights reserved.
* 
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
* 
* * Redistributions of source code must retain the above copyright notice, this
*   list of conditions and the following disclaimer.
* 
* * Redistributions in binary form must reproduce the above copyright notice,
*   this list of conditions and the following disclaimer in the documentation
*   and/or other materials provided with the distribution.
* 
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
* OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*********************************************************************************
*
* This file is used to set compile-time Dynosprite engine parameters
* Note: after changing any of these parameters, the Dynosprite project
* should be cleaned and rebuilt.

***********************************************************
* Parameter: SOUND_METHOD       Values: 1,2
***********************************************************
* The Coco has an unfortunate design defect which makes it impossible to
* read the state of the joystick axes without disrupting any currently
* playing audio waveform.  For this reason, Dynosprite supports 2 different
* audio playback methods, which have different qualities.
*
* Method 1: leave DAC output level at half-range
* - Pros: This method minimizes the amplitude of the audio disruption when
*         reading the joystick or starting or stopping audio playback.  It
*         will work best for games with continuous music.
* - Cons: This method works best with the digital joystick reading function
*         and will have more noise when used with the analog 4-bit or 6-bit
*         functions.  This method will produce a low-amplitude hum (regardless
*         of whether or not a sound is playing) when used on a real Coco but a
*         louder hum when run under the Vcc or MESS emulators, due to
*         inaccurate behaviors in the emulators.
*
* Method 2: leave DAC output level at minimum range
* - Pros: This method will have no humming signal if the audio is not currently
*         playing.  This method is best if you can ensure that the joystick
*         axes values will not be read while any sound is playing.
* - Cons: This method will produce significant noise if the joystick axes are
*         read while a sound is playing.  This method will also produce noise
*         (a step function) each time that the audio playback is started or
*         stopped.

SOUND_METHOD            EQU     1

