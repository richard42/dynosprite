*********************************************************************************
* DynoSprite - input.asm
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

* This file contains functions for:
*   1. scanning the entire keyboard state and determining if specific keys are
*      pressed (used by menus)
*   2. reading the joystick axis positions and button states quickly (used
*      during gameplay)
*   3. reading the keyboard state quickly for arrow and A+Z keys (used during
*      gameplay).
* There are 3 different joystick reading functions which trade off their axis
* precision (digital, 4-bit, or 6-bit) with their run-time performance (CPU
* cycles) and how much they affect the output audio signal. You can use
* whichever joystick read function you want. If you're using SOUND_METHOD 2
* (see config.asm) then the audio output will not be affected by the joystick
* read, but you must also guarantee that a sound is not playing when the
* joystick read functions are called.

***********************************************************
* Input_ReadKeyboard
*   This function is called to update the global Input state variables with the current status
*   of the keyboard.  The value of each axis will be 0, 32, or 63, depending upon which arrow
*   keys are currently pressed.  The first joystick button is mapped to the Z key, and the
*   second joystick button is mapped to the A key.
*
* - IN:
* - OUT: 
* - Trashed: A, B, X, Y
***********************************************************
*
Input_ReadKeyboard
            jsr         Input_ScanKeyboardStateCurrent
            ldy         #Input_KeyMatrix
            jsr         Input_FindPressedKeys
            ldu         #32
            lda         #KEY_UP
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            ldu         #0
!           lda         #KEY_DOWN
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            leau        31,u
!           tfr         u,d
            stb         <Input_JoystickY
            ldu         #32
            lda         #KEY_LEFT
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            ldu         #0
!           lda         #KEY_RIGHT
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            leau        31,u
!           tfr         u,d
            stb         <Input_JoystickX
            ldu         #$FF
            lda         #KEY_A
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            leau        -Joy1Button2,u
!           lda         #KEY_Z
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            leau        -Joy1Button1,u
!           tfr         u,d
            stb         <Input_Buttons
            rts

***********************************************************
* Input_ReadStateDigital
*   This function is called to update the global state variables with the current status
*   of the joystick 0 X/Y axes and buttons.  This function is very fast and can be used
*   with audio output, as it only creates a very faint buzzing sound.  The output value
*   for each axis will either be 0, 32, or 63.
*
* - IN:
* - OUT: 
* - Trashed: A, B
***********************************************************
JOYDEADZONE             EQU         8           * total deadzone is 8/64 (this number must be even)
*
Input_ReadStateDigital
 IFEQ SOUND_METHOD-2
            lda         #(PIA1B_Ctrl&$F7)       * clear CB2 output (disable audio on SC77526 chip)
            sta         $FF23
 ENDC
            orcc        #$50                    * Disable interrupts to we don't mess this up when the sound/timer IRQ fires
            ldb         $FF20                   * save the original 6-bit audio output value
            lda         #($7E+JOYDEADZONE*2)
            sta         $FF20
            tst         $FF00                   * check comparator result
            bpl         XNotHigh@
            lda         #63                     * X is in + position
            sta         <Input_JoystickX
            bra         EndJoyX@
XNotHigh@
            lda         #($7E-JOYDEADZONE*2)
            sta         $FF20
            tst         $FF00                   * check comparator result
            bpl         XLow@
            lda         #32
            sta         <Input_JoystickX
            bra         EndJoyX@
XLow@
            clr         <Input_JoystickX
EndJoyX@
            lda         #(PIA0A_Ctrl+8)         * set joystick axis selector to axis 1
            sta         $FF01
            lda         #($7E+JOYDEADZONE*2)
            sta         $FF20
            leas        ,s++                    * 7 / 6 cycle NOP to let joystick axis selector settle
            leas        ,s++                    * 7 / 6 cycle NOP to let joystick axis selector settle
            tst         $FF00                   * check comparator result
            bpl         YNotHigh@
            lda         #63                     * Y is in + position
            sta         <Input_JoystickY
            bra         EndJoyY@
YNotHigh@
            lda         #($7E-JOYDEADZONE*2)
            sta         $FF20
            tst         $FF00                   * check comparator result
            bpl         YLow@
            lda         #32
            sta         <Input_JoystickY
            bra         EndJoyY@
YLow@
            clr         <Input_JoystickY
EndJoyY@
            lda         #(PIA0A_Ctrl)           * clear CA2 (SELA on SC77526 audio/DAC chip)
            sta         $FF01
            stb         $FF20                   * restore the previous DAC value (for audio)
 IFEQ SOUND_METHOD-2
            tst         <Sound_ChannelsPlaying
            beq         AudioNotRunning@
            tst         <Sound_OutputMode
            bne         AudioNotRunning@        * only re-enable when audio mode is: Internal 6-bit DAC
            lda         #(PIA1B_Ctrl|$08)       * DAC6 mode: re-enable audio output on SC77526 chip
            sta         $FF23
AudioNotRunning@
 ENDC
            andcc       #$AF                    * re-enable interrupts
            * read joystick button state
            lda         #$FF
            sta         $FF02                   * set all keyboard column outputs to 1, to ignore keypresses
            lda         $FF00
            sta         <Input_Buttons
            rts

 IFDEF ANALOG_JOYSTICK

***********************************************************
* Input_ReadStateAnalog4bit
*   This function is called to update the global state variables with the current status
*   of the joystick 0 X/Y axes and buttons.  This function is relatively fast, but will create
*   a noticable buzzing sound if used with audio.
*   The output values for each axis will be between 1 and 61, in 4-value intervals.
*
* - IN:
* - OUT: 
* - Trashed: A, B, X
***********************************************************

Input_ReadStateAnalog4bit
            orcc        #$50                    * Disable interrupts to we don't mess this up when the sound/timer IRQ fires
            pshs        dp
            lda         #$ff
            tfr         a,dp
 IFEQ SOUND_METHOD-2
            lda         #(PIA1B_Ctrl&$F7)       * clear CB2 output (disable audio on SC77526 chip)
            sta         <$23
 ENDC
            ldb         <$20                    * save the original 6-bit audio output value
            ldx         #Input_JoystickX
SA_00_63@
            lda         #$7E                    * set to 31
            sta         <$20
            tst         <$00                     * check comparator result
            bpl         SA_00_31@
SA_32_63@
            adda        #64                     * set to 47
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_32_47@
SA_48_63@
            adda        #32                     * set to 55
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_48_55@
SA_56_63@
            adda        #16                     * set to 59
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_56_59@
SA_60_63@
            lda         #61                     * final result
            bra         SA_AxisDone@
SA_56_59@
            lda         #57                     * final result
            bra         SA_AxisDone@
SA_48_55@
            suba        #16                     * set to 51
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_48_51@
SA_52_55@
            lda         #53                     * final result
            bra         SA_AxisDone@
SA_48_51@
            lda         #49                     * final result
            bra         SA_AxisDone@
SA_32_47@
            suba        #32                     * set to 39
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_32_39@
SA_40_47@
            adda        #16                     * set to 43
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_40_43@
SA_44_47@
            lda         #45                     * final result
            bra         SA_AxisDone@
SA_40_43@
            lda         #41                     * final result
            bra         SA_AxisDone@
SA_32_39@
            suba        #16                     * set to 35
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_32_35@
SA_36_39@
            lda         #37                     * final result
            bra         SA_AxisDone@
SA_32_35@
            lda         #33                     * final result
SA_AxisDone@
            sta         ,x+
            cmpx        #Input_JoystickY
            bhi         SA_BothAxisDone@
            lda         #(PIA0A_Ctrl+8)         * set joystick axis selector to axis 1
            sta         <$01
            leas        ,s++                    * 7 / 6 cycle NOP to let joystick axis selector settle
            leas        ,s++                    * 7 / 6 cycle NOP to let joystick axis selector settle
            bra         SA_00_63@
SA_BothAxisDone@
            lda         #(PIA0A_Ctrl)           * clear CA2 (SELA on SC77526 audio/DAC chip)
            sta         <$01
            stb         <$20                    * restore the previous DAC value (for audio)
            * read joystick button state
            lda         #$FF
            sta         <$02                   * set all keyboard column outputs to 1, to ignore keypresses
            lda         <$00
            puls        dp
            sta         <Input_Buttons
 IFEQ SOUND_METHOD-2
            tst         <Sound_ChannelsPlaying
            beq         AudioNotRunning@
            tst         <Sound_OutputMode
            bne         AudioNotRunning@        * only re-enable when audio mode is: Internal 6-bit DAC
            lda         #(PIA1B_Ctrl|$08)       * DAC6 mode: re-enable audio output on SC77526 chip
            sta         $FF23
AudioNotRunning@
 ENDC
            andcc       #$AF                    * re-enable interrupts
            rts
SA_00_31@
            suba        #64                     * set to 15
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_00_15@
SA_16_31@
            adda        #32                     * set to 23
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_16_23@
SA_24_31@
            adda        #16                     * set to 27
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_24_27@
SA_28_31@
            lda         #29                     * final result
            bra         SA_AxisDone@
SA_24_27@
            lda         #25                     * final result
            bra         SA_AxisDone@
SA_16_23@
            suba        #16                     * set to 19
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_16_19@
SA_20_23@
            lda         #21                     * final result
            bra         SA_AxisDone@
SA_16_19@
            lda         #17                     * final result
            bra         SA_AxisDone@
SA_00_15@
            suba        #32                     * set to 7
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_00_07@
SA_08_15@
            adda        #16                     * set to 11
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_08_11@
SA_12_15@
            lda         #13                     * final result
            bra         SA_AxisDone@
SA_08_11@
            lda         #9                      * final result
            bra         SA_AxisDone@
SA_00_07@
            suba        #16                     * set to 3
            sta         <$20
            tst         <$00                    * check comparator result
            bpl         SA_00_03@
SA_04_07@
            lda         #5                      * final result
            bra         SA_AxisDone@
SA_00_03@
            lda         #1                      * final result
            lbra         SA_AxisDone@

***********************************************************
* Input_ReadStateAnalog6bit
*   This function is called to update the global state variables with the current status
*   of the joystick 0 X/Y axes and buttons.  This function calls ReadJoyAxis, which is an
*   optimized successive-approximation algorithm capable of calculating 6 bits of accuracy.
*   This function will create a buzzing sound if used with audio.
*   The output values for each axis will be between 0 and 63.
*
* - IN:
* - OUT: 
* - Trashed: A, B, X
***********************************************************

Input_ReadStateAnalog6bit
 IFEQ SOUND_METHOD-2
            lda         #(PIA1B_Ctrl&$F7)       * clear CB2 output (disable audio on SC77526 chip)
            sta         $FF23
 ENDC
            * read both joystick axes of joystick #1
            lda         #0
            jsr         Input_ReadJoyAxis
            sta         <Input_JoystickX
            lda         #1
            jsr         Input_ReadJoyAxis
            sta         <Input_JoystickY
 IFEQ SOUND_METHOD-2
            tst         <Sound_ChannelsPlaying
            beq         AudioNotRunning@
            tst         <Sound_OutputMode
            bne         AudioNotRunning@        * only re-enable when audio mode is: Internal 6-bit DAC
            lda         #(PIA1B_Ctrl|$08)       * DAC6 mode: re-enable audio output on SC77526 chip
            sta         $FF23
AudioNotRunning@
 ENDC
            * read joystick button state
            lda         #$FF
            sta         $FF02                   * set all keyboard column outputs to 1, to ignore keypresses
            lda         $FF00
            sta         <Input_Buttons
            rts

***********************************************************
* Input_ReadJoyAxis
* - IN:      A = joystick/axis selector (0-3)
* - OUT:     A = analog joystick axis value (0-63)
* - Trashed: B
***********************************************************
*
Input_ReadJoyAxis
            lsla
            lsla
            tfr         a,b
            lsla
            anda        #$08
            andb        #$08
            orcc        #$50                    * Disable interrupts to we don't mess this up when the sound/timer IRQ fires
            * set joystick axis selector output signals
            ora         #(PIA0A_Ctrl)           * PIA 1 control register A
            orb         #(PIA0B_Ctrl)           * PIA 1 control register B
            sta         $FF01
            stb         $FF03
            * initialize our min and max
            clr         <in_MinValue
            lda         #$7E
            sta         <in_MaxValue
            ldb         $FF20                   * save the original 6-bit audio output value
            * Successive Approximation loop
SALoop@
            lda         <in_MinValue            * start by calculating midpoint and setting D/A
            adda        <in_MaxValue
            ora         #2                      * serial out bit set to 1 so we don't confuse DriveWire
            sta         $FF20
            tst         $FF00                   * check comparator result
            bpl         LessOrEqual@
Higher@
            lsra                                * midpoint+1 will become minimum of range
            inca
            sta         <in_MinValue
            cmpa        <in_MaxValue            * if min and max are the same then we have found it
            beq         FoundResult@
            bra         SALoop@
LessOrEqual@
            lsra
            deca
            sta         <in_MaxValue            * midpoint will become maximum of range
            cmpa        <in_MinValue            * if min and max are the same then we have found it
            bne         SALoop@
FoundResult@                                    * B contains the analog axis value
            lsra
            pshs        a
            * re-configure the PIA chips
            lda         #(PIA0A_Ctrl)           * clear CA2 (SELA on SC77526 audio/DAC chip)
            sta         $FF01
            lda         #(PIA0B_Ctrl)           * clear CB2 (SELB on SC77526 audio/DAC chip)
            sta         $FF03                   * SELA=0 SELB=0 selects DAC output for audio output
            stb         $FF20                   * restore the previous DAC value (for audio)
            andcc       #$AF                    * re-enable interrupts
            puls        a,pc

 ENDC * ANALOG_JOYSTICK

***********************************************************
* Input_ScanKeyboardStateCurrent
*   This function is relatively fast, and suitable for in-game use
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: A, B, U
***********************************************************
*
Input_ScanKeyboardStateCurrent
            ldu         #$FF00
            ldb         #$FF                    * first we measure the inputs with all columns high, so that
            stb         2,u                     * we can detect and mask any joystick buttons pressed
            ldb         ,u
            comb                                * Note: set C=1
            stb         <Input_JoyButtonMask    * joystick button mask is high when the button is pressed
            lda         #$FE                    * now we will read the key row signals for each column in the matrix
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix
            rola                                * shift column strobe value left by 1 bit, shifting in 1 bit on right
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+1
            rola
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+2
            rola
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+3
            rola
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+4
            rola
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+5
            rola
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+6
            rola
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask
            stb         <Input_KeyMatrix+7
            rts

***********************************************************
* Input_ScanKeyboardDebounced
*   This function is slow, and should only be used for menus
*
* - IN:      N/A
* - OUT:     Carry flag set if one or more keys were just pressed, otherwise cleared
* - Trashed: A, B, X, Y, U
***********************************************************
*
Input_ScanKeyboardDebounced
            ldu         #$FF00
            ldb         #$FF                    * first we measure the inputs with all columns high, so that
            stb         2,u                     * we can detect and mask any joystick buttons pressed
            ldb         ,u
            comb                                * Note: set C=1
            stb         <Input_JoyButtonMask    * joystick button mask is high when the button is pressed
            ldy         #Input_KeyMatrix
            ldb         #$FE                    * now we will read the key row signals for each column in the matrix
            stb         LoadColMask@+1
ScanLoop@
            stb         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask    * joystick presses are masked out of the affected rows
            tfr         b,a
            eorb        ,y                      * bits in B are set if they have changed since the last keyboard scan
            andb        ,y                      * bits in B are set if the key has been pressed since the last keyboard scan
            sta         ,y+                     * store current raw matrix state (active low)
            comb                                * new keypress bitmap is inverted to active-low (also note C=1 here)
            stb         7,y                     * store bits corresponding with new key presses (active low)
LoadColMask@
            ldb         #0                      * SMC: column mask is stored in this instruction
            rolb                                * shift column strobe value left by 1 bit, shifting in 1 bit on right
            cmpb        #$FF
            beq         ScanDone@
            stb         LoadColMask@+1
            bra         ScanLoop@
ScanDone@
            * now test to see if there were any keys pressed at all
            lda         <Input_KeyMatrixDB
            anda        <Input_KeyMatrixDB+1
            anda        <Input_KeyMatrixDB+2
            anda        <Input_KeyMatrixDB+3
            anda        <Input_KeyMatrixDB+4
            anda        <Input_KeyMatrixDB+5
            anda        <Input_KeyMatrixDB+6
            anda        <Input_KeyMatrixDB+7
            ora         #$80                    * mask off the comparator bit
            cmpa        #$FF
            bne         KeyWasHit@
            clra                                * clear C flag; no keys were pressed
            rts
KeyWasHit@
            ldx         #$45E                   * debounce timer = 1118 * 8 / 1987772.5 = 4.5ms
!           leax        -1,x
            bne         <                       * loop until 4.5 milliseconds have passed
            ldb         #$FF                    * measure for joystick button presses again
            stb         2,u
            ldb         ,u
            comb                                * Note: set C=1
            stb         <Input_JoyButtonMask    * joystick button mask is high when the button is pressed
            ldy         #Input_KeyMatrix
            lda         #$FE                    * now we will read the key row signals for each column in the matrix
ScanLoop2@
            sta         2,u
            ldb         ,u
            orb         <Input_JoyButtonMask    * B is now current KB column state (active low) with masked joystick button presses
            stb         ,y+                     * update current state
            orb         7,y                     * each bit is now cleared only if key was newly pressed and remained pressed after debounce delay
            stb         7,y                     * store final debounced and one-shotted row values
            rola                                * shift column strobe value left by 1 bit, shifting in 1 bit on right
            bcs         ScanLoop2@              * loop until we've tested all of the columns
            coma                                * set Carry flag (a key was pressed)
            rts

***********************************************************
* Input_FindPressedKeys
* - IN:      Y = pointer to keyboard matrix array (debounced or not)
* - OUT:     N/A
* - Trashed: A, B, X, Y
***********************************************************
*
Input_FindPressedKeys
            * scan the matrix and store keycodes for any pressed keys
            clr         <Input_NumPressedKeys
            ldx         #Input_PressedKeyCodes
            ldb         #0
KeyReadOuter@
            lda         ,y+
            ora         #$80                    * mask out comparator bit
            coma                                * now the pressed key bitmap is active-high
            beq         ColumnIdle@             * no keys were pressed in this column
            * a key was pressed; let's find out which one
            pshs        b
KeyReadInner@
            bita        #1
            beq         NotThisRow@
            stb         ,x+                     * the pressed keycode is in B
            inc         <Input_NumPressedKeys
            cmpx        #Input_PressedKeyCodes+8
            beq         KeyBufFull@
NotThisRow@
            addb        #$10                    * go to next row
            lsra
            bne         KeyReadInner@
            puls        b
ColumnIdle@
            incb            
            cmpb        #8
            bne         KeyReadOuter@
            rts
KeyBufFull@
            puls        b
            rts

***********************************************************
* Input_IsKeyPressed
* - IN:      A = key to look for
* - OUT:     B = 0 if key is not pressed
* - Trashed: A, B, X
***********************************************************
*
Input_IsKeyPressed
            ldb         <Input_NumPressedKeys
            bne         >
            rts
!           ldx         #Input_PressedKeyCodes
PressLoop@
            cmpa        ,x+
            bne         >
            rts
!           decb
            bne         PressLoop@
            rts


