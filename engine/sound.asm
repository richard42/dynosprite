*********************************************************************************
* DynoSprite - sound.asm
* Copyright (c) 2013-2014, Richard Goedeken
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


***********************************************************
* Sound_Play
*   This function begins playback of a waveform
*
* - IN:      B = Waveform # to play
* - OUT: 
* - Trashed: A, B, X, Y, U
***********************************************************
*
Sound_Play
 IFDEF DEBUG
            cmpb        Gamedir_Sounds          * check requested waveform number
            blo         >
            swi                                 * invalid waveform # requested for playback
 ENDC
!           tst         <Sound_OutputMode       * if audio Output Mode == No Sound, then just return
            bpl         >
            rts
!           ldx         #Gamedir_Sounds+1
            lslb                                * Note: this code will only work for up to 64 waveforms.
            lslb                                * to work properly up to 256, we need to use 16-bit arithmetic here
            abx                                 * X is pointer to Gamedir_Sounds entry for waveform to play
            orcc        #$50                    * disable interrupts
            lda         <Sound_ChannelsPlaying
            cmpa        #3
            bne         >
            andcc       #$AF
            rts                                 * exit without playing this waveform: 2 sounds already playing
!           ldu         #Sound_Chan0VPage
            ldb         2,x                     * virtual page index is in upper 3 bits
            lsrb
            lsrb
            lsrb
            lsrb
            lsrb
            addb        #VH_SOUNDDATA
            tsta
            beq         NoSoundsPlaying@
            * One sound currently playing, so we must enable the other sound channel and get in with the next buffer refill
            cmpa        #1
            bne         >
            leau        5,u                     * U is pointer to channel entry to enable
!           stb         ,u                      * store Chan*VPage
            ldd         2,x
            anda        #$1f
            std         1,u                     * store Chan*Ptr
            addd        ,x
            std         3,u                     * store Chan*End
            lda         #3
            sta         <Sound_ChannelsPlaying  * activate both channels
            andcc       #$AF                    * re-enable interrupts
            rts
NoSoundsPlaying@
            andcc       #$AF                    * re-enable interrupts
            stb         ,u                      * store Chan0VPage
            ldd         2,x
            anda        #$1f
            std         1,u                     * store Chan0Ptr
            addd        ,x
            std         3,u                     * store Chan0End
            lda         #1
            sta         <Sound_ChannelsPlaying  * activate channel 0
            jsr         Sound_RefillBuffer      * load up the 256-byte audio output buffer
            ldx         #Sound_PageBuffer
            stx         System_SndBufferPtr     * set output pointer to head of buffer
            lda         ,x                      * load first sample of waveform being played
            tst         <Sound_OutputMode
            beq         FirstSample_DAC6@
FirstSample_Orc90@
            sta         $FF7A
            sta         $FF7B
            bra         FirstSampleDone@
FirstSample_DAC6@
            ora         #2                      * serial out bit set to 1 so we don't confuse DriveWire
            sta         $FF20                   * store in output DAC register
            lda         #(PIA1B_Ctrl|$08)       * (enable audio output on SC77526 chip).  Note: we must do this even
            sta         $FF23                   * for SOUND_METHOD 1, because HDB-DOS may disable sound while talking to DW4 server
FirstSampleDone@
            ldd         #(3579545/AudioSamplingRate)-1
            jmp         System_EnableAudioInterrupt      * start audio playback

***********************************************************
* Sound_RefillBuffer
*   This function reloads the Audio_PageBuffer based upon the channels currently enabled
*
* - IN:      DP may be invalid (if called from FIRQ)
* - OUT: 
* - Trashed: A, B, X, Y, U
***********************************************************
*
Sound_RefillBuffer
            * Begin by disabling channels which are finished playing their waveform
            lda         Sound_ChannelsPlaying
            bita        #1
            beq         Channel0TestDone@
            ldx         Sound_Chan0Ptr
            cmpx        Sound_Chan0End
            blo         Channel0TestDone@
            anda        #$fe                    * disable channel 0
Channel0TestDone@
            bita        #2
            beq         Channel1TestDone@
            ldx         Sound_Chan1Ptr
            cmpx        Sound_Chan1End
            blo         Channel1TestDone@
            anda        #$fd                    * disable channel 1
Channel1TestDone@
            sta         Sound_ChannelsPlaying
            bne         StillRunning@
 IFEQ SOUND_METHOD-2
            lda         #(PIA1B_Ctrl&$F7)       * clear CB2 output (disable audio on SC77526 chip)
            sta         $FF23
 ENDC
            jmp         System_DisableAudioInterrupt     * turn off timer counter and timer FIRQ signal
StillRunning@
            ldx         #Sound_Chan0VPage
            cmpa        #3
            beq         BothChannelsRunning@
            cmpa        #1
            beq         >
            leax        5,x
!           lda         $FFA2                   * X is pointer to Chan*VPage for active channel
            anda        #$3F
            sta         <PreMappedPages@,PCR
            lda         ,x
            ldy         #MemMgr_VirtualTable
            lda         a,y                     * get physical block for this virtual block handle
            sta         $FFA2                   * map page w/ raw audio data at $4000
            ldu         1,x
            leau        $4000,u                 * U is pointer to start copying
            andcc       #$AF                    * enable interrupts, in case we were called from timer FIRQ
 IFEQ CPU-6309
            pshsw
            ldw         #256                    * 4
            ldy         #Sound_PageBuffer       * 4
            tfm         u+,y+                   * 774
            pulsw
 ELSE
            pshs        x                       * 7
            ldx         #Sound_PageBuffer       * 3
CopyOneChannelLoop@
            ldd         ,u                      * 5
            std         ,x                      * 5
            ldd         2,u                     * 6
            std         2,x                     * 6
            ldd         4,u                     * 6
            std         4,x                     * 6
            ldd         6,u                     * 6
            std         6,x                     * 6
            ldd         8,u                     * 6
            std         8,x                     * 6
            ldd         10,u                    * 6
            std         10,x                    * 6
            ldd         12,u                    * 6
            std         12,x                    * 6
            ldd         14,u                    * 6
            std         14,x                    * 6
            leau        16,u                    * 5
            leax        16,x                    * 5
            cmpx        #Sound_PageBuffer+256   * 4
            bne         CopyOneChannelLoop@     * 3
            puls        x                       * 7
 ENDC
            inc         1,x                     * update Chan*Ptr
            lda         <PreMappedPages@,PCR
            sta         $FFA2                   * re-map the page that was previously at $4000
            rts
*
PreMappedPages@         zmb     2
*
BothChannelsRunning@
            ldd         $FFA2
            anda        #$3F
            andb        #$3F
            std         <PreMappedPages@,PCR
            ldy         #MemMgr_VirtualTable
            lda         ,x
            lda         a,y
            ldb         5,x
            ldb         b,y
            std         $FFA2                   * map pages w/ raw audio data at $4000 and $6000
            clrb                                * B is number of bytes to copy (0 == 256)
            ldu         1,x
            leau        $4000,u                 * U is pointer to Channel 0 waveform data
            ldy         6,x
            leay        $6000,y                 * Y is pointer to Channel 1 waveform data
            inc         1,x                     * update Chan0Ptr
            inc         6,x                     * update Chan1Ptr
            ldx         #Sound_PageBuffer
            andcc       #$AF                    * enable interrupts, in case we were called from timer FIRQ
            tst         Sound_OutputMode
            beq         TwoChan_DAC6@
TwoChan_Orc90@
 IFEQ CPU-6309
            pshsw
CopyTwoChannelsOrc90_6309@                      * Total: 2544
            ldq         ,u                      * 8
            addd        ,y                      * 5
            rord                                * 2
            addw        2,y                     * 7
            rorw                                * 2
            stq         ,x                      * 8
            ldq         4,u                     * 9
            addd        4,y                     * 6
            rord                                * 2
            addw        6,y                     * 7
            rorw                                * 2
            stq         4,x                     * 9
            ldq         8,u                     * 9
            addd        8,y                     * 6
            rord                                * 2
            addw        10,y                    * 7
            rorw                                * 2
            stq         8,x                     * 9
            ldq         12,u                    * 9
            addd        12,y                    * 6
            rord                                * 2
            addw        14,y                    * 7
            rorw                                * 2
            stq         12,x                    * 9
            leau        16,u                    * 5
            leay        16,y                    * 5
            leax        16,x                    * 5
            cmpx        #Sound_PageBuffer+256   * 4
            bne         CopyTwoChannelsOrc90_6309@    * 3
            pulsw
 ELSE
CopyTwoChannelsOrc90_6809@                      * Total: 3248
            ldd         ,u                      * 5
            addd        ,y                      * 6
            rora                                * 2
            rorb                                * 2
            std         ,x                      * 5
            ldd         2,u                     * 6
            addd        2,y                     * 7
            rora                                * 2
            rorb                                * 2
            std         2,x                     * 6
            ldd         4,u                     * 6
            addd        4,y                     * 7
            rora                                * 2
            rorb                                * 2
            std         4,x                     * 6
            ldd         6,u                     * 6
            addd        6,y                     * 7
            rora                                * 2
            rorb                                * 2
            std         6,x                     * 6
            ldd         8,u                     * 6
            addd        8,y                     * 7
            rora                                * 2
            rorb                                * 2
            std         8,x                     * 6
            ldd         10,u                    * 6
            addd        10,y                    * 7
            rora                                * 2
            rorb                                * 2
            std         10,x                    * 6
            ldd         12,u                    * 6
            addd        12,y                    * 7
            rora                                * 2
            rorb                                * 2
            std         12,x                    * 6
            ldd         14,u                    * 6
            addd        14,y                    * 7
            rora                                * 2
            rorb                                * 2
            std         14,x                    * 6
            leau        16,u                    * 5
            leay        16,y                    * 5
            leax        16,x                    * 5
            cmpx        #Sound_PageBuffer+256   * 4
            bne         CopyTwoChannelsOrc90_6809@    * 3
 ENDC
            bra         TwoChannelsDone@
TwoChan_DAC6@
 IFEQ CPU-6309
            pshsw
            ldd         #$0202
            tfr         d,v
CopyTwoChannelsDAC6_6309@                       * Total: 3056
            ldq         ,u                      * 8
            addd        ,y                      * 5
            rord                                * 2
            addw        2,y                     * 7
            rorw                                * 2
            ord         #$0202                  * 4
            orr         v,w                     * 4
            stq         ,x                      * 8
            ldq         4,u                     * 9
            addd        4,y                     * 6
            rord                                * 2
            addw        6,y                     * 7
            rorw                                * 2
            ord         #$0202                  * 4
            orr         v,w                     * 4
            stq         4,x                     * 9
            ldq         8,u                     * 9
            addd        8,y                     * 6
            rord                                * 2
            addw        10,y                    * 7
            rorw                                * 2
            ord         #$0202                  * 4
            orr         v,w                     * 4
            stq         8,x                     * 9
            ldq         12,u                    * 9
            addd        12,y                    * 6
            rord                                * 2
            addw        14,y                    * 7
            rorw                                * 2
            ord         #$0202                  * 4
            orr         v,w                     * 4
            stq         12,x                    * 9
            leau        16,u                    * 5
            leay        16,y                    * 5
            leax        16,x                    * 5
            cmpx        #Sound_PageBuffer+256   * 4
            bne         CopyTwoChannelsDAC6_6309@    * 3
            pulsw
 ELSE
CopyTwoChannelsDAC6_6809@                       * Total: 3760
            ldd         ,u                      * 5
            addd        ,y                      * 6
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         ,x                      * 5
            ldd         2,u                     * 6
            addd        2,y                     * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         2,x                     * 6
            ldd         4,u                     * 6
            addd        4,y                     * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         4,x                     * 6
            ldd         6,u                     * 6
            addd        6,y                     * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         6,x                     * 6
            ldd         8,u                     * 6
            addd        8,y                     * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         8,x                     * 6
            ldd         10,u                    * 6
            addd        10,y                    * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         10,x                    * 6
            ldd         12,u                    * 6
            addd        12,y                    * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         12,x                    * 6
            ldd         14,u                    * 6
            addd        14,y                    * 7
            rora                                * 2
            rorb                                * 2
            ora         #2                      * 2
            orb         #2                      * 2
            std         14,x                    * 6
            leau        16,u                    * 5
            leay        16,y                    * 5
            leax        16,x                    * 5
            cmpx        #Sound_PageBuffer+256   * 4
            bne         CopyTwoChannelsDAC6_6809@    * 3
 ENDC
TwoChannelsDone@
            ldd         PreMappedPages@,PCR
            std         $FFA2                   * re-map the pages that were previously at $4000 and $6000
            rts

