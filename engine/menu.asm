*********************************************************************************
* DynoSprite - menu.asm
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

*Local Data
*
Menu_Monitor            fcn     '[M]onitor:'
Menu_RGB                fcn     'RGB'
Menu_CMP                fcn     'Composite'
Menu_Control            fcn     '[C]ontrol:'
Menu_Joystick           fcn     'Joystick'
Menu_Keyboard           fcn     'Keyboard'
Menu_Sound              fcn     '[S]ound:'
Menu_Internal           fcn     'Coco internal'
Menu_Orc90              fcn     'Orchestra-90'
Menu_NoSound            fcn     'No sound'
Menu_StartMsg           fcn     '[Space] or joystick button to start'

***********************************************************
* Menu_RunMain:
*   This function never returns.  When the player starts the game, this routine
*   will load and execute the first level.
*
* - IN:      N/A
* - OUT:     This function never returns
***********************************************************
*
Menu_RunMain
            * Initialize the graphics aperature, prior to allocating any virtual 8k blocks
            ldy         #0                      * setup Gfx_BkgrndStartXYList
            ldx         #0
            stx         <Gfx_BkgrndStartXYList
            sty         <Gfx_BkgrndStartXYList+2
            stx         <Gfx_BkgrndStartXYList+4
            sty         <Gfx_BkgrndStartXYList+6
            stx         <Gfx_BkgrndNewX         * set up NewX/Y and RedrawOldX/Y globals so 2nd frame will be drawn in correct place
            stx         <Gfx_BkgrndRedrawOldX
            sty         <Gfx_BkgrndNewY
            sty         <Gfx_BkgrndRedrawOldY
            jsr         Gfx_SetInitialAperature * Initialize graphics aperature
            clra
            jsr         System_SetPaletteConst  * set palette to all 0
            * Set up double-buffering variables
            clr         <Gfx_CurrentFieldCount
            orcc        #$50                    * disable interrupts
            clr         <Gfx_LastRenderedFrame
            clr         <Gfx_DisplayedFrame
            andcc       #$AF                    * re-enable interrupts
            ldb         #4
            stb         <Gfx_RenderingFrameX4   * set back buffer to second pair
            ldx         #Gfx_BkgrndStartXYList  * set both physical addresses
            jsr         Gfx_UpdatePhyAddress
            ldx         #Gfx_BkgrndStartXYList+4
            jsr         Gfx_UpdatePhyAddress
            clrb
            jsr         System_SetVideoStart    * then set GIME video start address for correct buffer pair
            * Load main menu splash image (Image #0)
            clra
            clrb
            ldu         #0
            jsr         Img_Load_Splash_Image
            * Draw menu text on top of the splash image
            clra
            ldb         Gfx_PalIdx_BarColor
            andb        #$0f
            tfr         d,u
            pshs        u
            ldx         #Menu_Monitor
            ldb         #3
            lda         #120
            jsr         Gfx_DrawTextLine_Back
            ldx         #Menu_Control
            ldb         #3
            lda         #136
            ldu         ,s
            jsr         Gfx_DrawTextLine_Back
            ldx         #Menu_Sound
            ldb         #3
            lda         #152
            ldu         ,s
            jsr         Gfx_DrawTextLine_Back
            ldx         #Menu_StartMsg
            ldb         #10
            lda         #184
            puls        u
            jsr         Gfx_DrawTextLine_Back
            clra
            ldb         Gfx_PalIdx_FGColor
            andb        #$0f
            tfr         d,u
            pshs        u
            ldx         #Menu_CMP
            tst         <Gfx_MonitorIsRGB
            beq         >
            ldx         #Menu_RGB
!           ldb         #5+10*4
            lda         #120
            jsr         Gfx_DrawTextLine_Back
            ldx         #Menu_Joystick
            tst         <Input_UseKeyboard
            beq         >
            ldx         #Menu_Keyboard
!           ldb         #5+10*4
            lda         #136
            ldu         ,s
            jsr         Gfx_DrawTextLine_Back
            ldx         #Menu_NoSound
            tst         <Sound_OutputMode
            bmi         SoundMenuInitTextDone@
            bgt         >
            ldx         #Menu_Internal
            bra         SoundMenuInitTextDone@
!           ldx         #Menu_Orc90
            ldx         #Menu_Internal
SoundMenuInitTextDone@
            ldb         #5+8*4
            lda         #152
            puls        u
            jsr         Gfx_DrawTextLine_Back
            * clear front buffer and set the new palette
            clra
            jsr         Gfx_FillScreen_Front
            jsr         System_SetPaletteAuto
            * fade in to the menu
            lda         #1
            jsr         Img_FadeIn
MenuKeyLoop@
            jsr         Input_ScanKeyboardDebounced
            bcc         CheckJoyButton@
            ldy         #Input_KeyMatrixDB
            jsr         Input_FindPressedKeys
            lda         #KEY_M
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            jsr         Menu_Keypress_M
!           lda         #KEY_C
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            jsr         Menu_Keypress_C
!           lda         #KEY_S
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            jsr         Menu_Keypress_S
!           lda         #KEY_SPACE
            jsr         Input_IsKeyPressed
            tstb
            beq         >
            jmp         Menu_Keypress_Space     * this starts a level and doesn't return, so jump there
CheckJoyButton@
            * read joystick button state
!           ldb         <Input_JoyButtonMask
            bitb        #Joy1Button1
            beq         >
            jmp         Menu_Keypress_Space     * this starts a level and doesn't return, so jump there
!           bra         MenuKeyLoop@

Menu_Keypress_C
            * flip state of Controller option
            com         <Input_UseKeyboard
            * wait for next vertical retrace to start
            sync
            * erase box around option text
            ldb         #5+10*4
            lda         #136
            ldu         #8
            jsr         Menu_EraseBox
            * redraw new option value
            ldx         #Menu_Joystick
            tst         <Input_UseKeyboard
            beq         >
            ldx         #Menu_Keyboard
!           clra
            ldb         Gfx_PalIdx_FGColor
            andb        #$0f
            tfr         d,u
            ldb         #5+10*4
            lda         #136
            jsr         Gfx_DrawTextLine
            rts

Menu_Keypress_S
            * advance state of Sound option
            lda         <Sound_OutputMode
            inca
            cmpa        #2
            blt         >
            lda         #-1
!           sta         <Sound_OutputMode
            * wait for next vertical retrace to start
            sync
            * erase box around option text
            ldb         #5+8*4
            lda         #152
            ldu         #13
            jsr         Menu_EraseBox
            * redraw new option value
            ldx         #Menu_NoSound
            tst         <Sound_OutputMode
            bmi         SoundMenuTextDone@
            bgt         >
            ldx         #Menu_Internal
            bra         SoundMenuTextDone@
!           ldx         #Menu_Orc90
SoundMenuTextDone@
            clra
            ldb         Gfx_PalIdx_FGColor
            andb        #$0f
            tfr         d,u
            ldb         #5+8*4
            lda         #152
            jsr         Gfx_DrawTextLine
            * update audio hardware state if necessary
 IFEQ SOUND_METHOD-1
            tst         <Sound_OutputMode
            beq         >
            lda         #(PIA1B_Ctrl&$F7)       * set ORCC90/NoSound mode: disable audio on SC77526 chip
            sta         $FF23
            bra         AudioSwitchDone@
!           lda         #(PIA1B_Ctrl|$08)       * set DAC6 mod: enable audio on SC77526 chip
            sta         $FF23
            lda         #$82
            sta         $FF20                   * set DAC to mid-range, serial bit to 1
AudioSwitchDone@
 ENDC
            rts

Menu_Keypress_M
            * flip state of Monitor option
            com         <Gfx_MonitorIsRGB
            * wait for next vertical retrace to start
            sync
            * erase box around option text
            ldb         #5+10*4
            lda         #120
            ldu         #9
            jsr         Menu_EraseBox
            * redraw new option value
            ldx         #Menu_CMP
            tst         <Gfx_MonitorIsRGB
            beq         >
            ldx         #Menu_RGB
!           clra
            ldb         Gfx_PalIdx_FGColor
            andb        #$0f
            tfr         d,u
            ldb         #5+10*4
            lda         #120
            jsr         Gfx_DrawTextLine
            * set new palette
            jsr         System_SetPaletteAuto
            rts

Menu_Keypress_Space
            * fade out to background color (white)
            lda         #0
            jsr         Img_FadeOut
            * then set all palette entries to white
            lda         #63
            jsr         System_SetPaletteConst
            * mark the graphics aperature as free
            jsr         MemMgr_FreeGfxAperature
            * load and execute Level 1
            lda         #1                      * Level #1
            jmp         Ldr_Load_Level          * jump to loader (it does not return, but jumps to mainloop)


***********************************************************
* Menu_EraseBox:
*   This function writes the background color to a one-row block of text, erasing a text line
*
* - IN:      A=Y coordinate, B=X coordinate, U=Number of characters to erase horizontally
* - OUT:     N/A
* - Trashed: All
***********************************************************
*
Menu_EraseBox
            jsr         Gfx_GetPixelAddress_Front   * (A=page number, Y=offset)
            sta         $FFA2                   * map starting graphics pages to $4000-$7FFF
            inca
            sta         $FFA3
            leay        $4000,y                 * Y is destination pointer (upper-left corner)
            tfr         u,d
            lslb
            lslb                                * 4 bytes (8 pixels) per character
            stb         ClearLoopRow@+1
            ldx         #16                     * X is row counter
            ldb         Gfx_PalIdx_BKColor
ClearLoopRow@
            lda         #0                      * SMC: width of block to erase is store in code above
            pshs        y
ClearLoopCol@
            stb         ,y+
            deca
            bne         ClearLoopCol@
            puls        y
            leay        256,y
!           leax        -1,x
            bne         ClearLoopRow@
            rts

