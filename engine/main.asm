*********************************************************************************
* DynoSprite - main.asm
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
*           These initial assembly files don't emit any assembly code

            include     config.asm
            include     constants.asm
            include     datastruct.asm
            include     macros.asm

*           The core of DynoSprite is in the $2000-$3FFF page
*           Starting with the direct page globals at $2000

            org         $2000
            include     globals.asm
            include     utility.asm
            include     math.asm
            include     system.asm
            include     memory.asm
            include     object.asm
            include     loader.asm
            include     input.asm
            include     sound.asm
            include     menu.asm
            include     graphics-sprite.asm

***********************************************************
* Startup code

start       lds         #$4000                  * move stack to top of DynoSprite primary code page
            lda         #$20                    * set DP to our global data page at $2000 in globals.asm
            tfr         a,dp
            jsr         System_InitHardware
            jsr         MemMgr_Init             * initialize the virtual memory table
            clra
            jsr         System_SetPaletteConst
            jsr         System_EnableGraphics   * go into graphics mode
            jsr         MemMgr_MoveCode
            jsr         Disk_DirInit            * read FAT and directory entries of disk in current drive
            jmp         Menu_RunMain            * load and display the main menu

***********************************************************
* Main loop

* High-level main loop flow:
* --------------------------
* 1. Wait until flip screen buffer
* 2. Erase all sprites drawn to offscreen buffer pair
* 3. Set new frame background position, update background pixels
* 4. Call Draw on all objects which have ((active & 2) != 0)
* 5. Increment LastRenderedFrame
* 6. Read input status
* 7. Calculate next frame background position
* 8. Iterate through each object in the Current Object Table:
*    - If (active & 1) == 0, then call reactivate function
*    - else call update function

mainloop
            * 1. Wait until vertical retrace IRQ has happened and we need to draw a new frame
            lda         <Gfx_LastRenderedFrame
            ldx         #0
!           cmpa        <Gfx_DisplayedFrame     * 4/3
            beq         beginframe              * 3
 IFDEF SPEEDTEST
            leax        1,x                     * 5
 ELSE
  IFNE CPU-6309
            sync                                * fixme: figure out why demo hangs up here with CPU=6309 and audio enabled
  ENDC
 ENDC
            bra         <                       * 3
beginframe
            * cpu runs at 1.7897725 MHz
 IFDEF SPEEDTEST
            lda         <Gfx_BkgrndNewX+1
            suba        <Gfx_BkgrndRedrawOldX+1
            ldb         <Gfx_BkgrndNewY+1
            subb        <Gfx_BkgrndRedrawOldY+1
 ENDC

            * 2. Erase all sprites drawn to offscreen buffer pair
            jsr         Gfx_SpriteEraseOffscreen

            * 3. Extend background pixels for new frame position
            *    This function expects valid values in Gfx_BkgrndRedrawOldX/Y and Gfx_BkgrndNewX/Y
            *    and it fills in the new frame's coordinates in Gfx_BkgrndStartXYList and the new
            *    screen start physical address
            jsr         Gfx_UpdateBackground

            * 4. Call Draw on all objects which have ((active & 2) != 0)
            ldb         <Gfx_RenderingFrameX4
            ldx         #Gfx_BkgrndPhyAddrList
            abx
            lda         ,x                      * cache the new frame's starting physical address
            ldx         1,x                     * for use by the drawing functions
            leax        48,x                    * add 48 bytes to get to visible screen start
            sta         <Gfx_DrawScreenPage
            stx         <Gfx_DrawScreenOffset
            ldx         #Gfx_SpriteErasePtrs
            abx
            stx         <Gfx_SpriteErasePtrPtr  * store pointer to erase pointer table for frame being drawn
            lda         <MemMgr_VirtualTable+VH_BASIC0      * map the BASIC0 block with heap into 6809 address space at $0000
            sta         $FFA0                   * this contains object tables
            lda         <MemMgr_VirtualTable+VH_SPRERASE
            sta         $FFA6                   * Map sprite erase data to $C000
            ldx         <Obj_CurrentTablePtr
            lda         <Obj_NumCurrent
            beq         DrawObjDone@
DrawObjLoop@
            ldb         COB.active,x
            andb        #2
            beq         SkipDraw@
            pshs        a,x
            ldu         COB.odtPtr,x
            ldb         ODT.drawType,u
            bne         >
            * custom drawing function
            lda         <MemMgr_VirtualTable+VH_LVLOBJCODE
            sta         $FFA3                   * Map the Level/Object code page to $6000
            jsr         [ODT.draw,u]
            bra         ThisObjDrawn@
!           cmpb        #1
            bne         >
            * standard sprite with no rowcrop
            jsr         Gfx_SpriteDrawSimple
            bra         ThisObjDrawn@
            * standard sprite with rowcrop
!           jsr         Gfx_SpriteDrawRowcrop
ThisObjDrawn@
            puls        a,x
SkipDraw@
            leax        sizeof{COB},x
            deca
            bne         DrawObjLoop@
DrawObjDone@

            * 5. Advance render frame counter so new frame will be shown at next vsync
            lda         <Gfx_CurrentFieldCount  * capture # of 60hz fields passed since last new frame displayed
            inc         <Gfx_LastRenderedFrame  * when vertical retrace IRQ hits, it will switch to the newly rendered frame
            ldb         <Gfx_LastRenderedFrame  * calculate index of next rendering buffer pair * 4
            andb        #1
            eorb        #1
            lslb
            lslb
            stb         <Gfx_RenderingFrameX4
            cmpa        #3
            blo         >
            lda         #2
!           deca
            sta         <Obj_MotionFactor       * A is number of 60hz fields dropped since last new frame displayed, minus one

            * 6. Read input status
            tst         <Input_UseKeyboard
            beq         >
            jsr         Input_ReadKeyboard
            bra         InputDone@
!           jsr         Input_ReadStateDigital
InputDone@

            * 7. Calculate next frame background position (update Gfx_BkgrndNewX/Y)
            lda         <MemMgr_VirtualTable+VH_LVLOBJCODE
            sta         $FFA3                   * Map Level/Object code page at $6000 (fixme: is this needed here?)
            jsr         [Ldr_LDD.PtrCalcBkgrnd]
            * Setup the RedrawOldX/Y coordinates for the next frame's background draw operation
            * and update the starting X,Y coordinate of the new buffer pair to render
            ldb         <Gfx_RenderingFrameX4
            ldx         #Gfx_BkgrndStartXYList
            abx                                 * X is the effective address of the X coordinate for the new frame
            ldu         ,x
            stu         <Gfx_BkgrndRedrawOldX
            ldu         2,x
            stu         <Gfx_BkgrndRedrawOldY
            * Clip the new frame starting background position to legal limits, and
            * Clip the New position coordinates so that the delta to redraw is within the background engine's legal limits
            ldd         <Gfx_BkgrndNewX
            bpl         >
            ldd         #0
!           cmpd        <Gfx_BkgrndStartXMax
            bls         >
            ldd         <Gfx_BkgrndStartXMax
!           subd        <Gfx_BkgrndRedrawOldX
            cmpb        #8
            ble         >
            ldb         #8
!           cmpb        #-8
            bge         >
            ldb         #-8
!           addd        <Gfx_BkgrndRedrawOldX
            std         <Gfx_BkgrndNewX
            std         ,x
            lslb
            rola
            std         <Gfx_BkgrndNewX2        * store X coordinate in pixels
            ldd         <Gfx_BkgrndNewY
            bpl         >
            ldd         #0
!           cmpd        <Gfx_BkgrndStartYMax
            bls         >
            ldd         <Gfx_BkgrndStartYMax
!           subd        <Gfx_BkgrndRedrawOldY
            cmpb        #12
            ble         >
            ldb         #12
!           cmpb        #-12
            bge         >
            ldb         #-12
!           addd        <Gfx_BkgrndRedrawOldY
            std         <Gfx_BkgrndNewY
            std         2,x

            * 8. Iterate through each object in the Current Object Table:
            *    - If (active & 1) == 0, then call reactivate function
            *    - else call update function
            * the 8k heap block should already be mapped into 6809 address space at $6000
            ldx         <Obj_CurrentTablePtr
            lda         <Obj_NumCurrent
            beq         UpdateObjDone@
UpdateObjLoop@
            pshs        a,x
            ldu         COB.odtPtr,x
            ldb         COB.active,x
            andb        #1
            beq         >
            * call Update function
            jsr         [ODT.update,u]
            bra         ThisObjUpdated@
            * call Reactivate function
!           jsr         [ODT.reactivate,u]
ThisObjUpdated@
            puls        a,x
            leax        sizeof{COB},x
            deca
            bne         UpdateObjLoop@
UpdateObjDone@

            * Begin main loop again and wait until new frame has begun to display
 IFDEF VISUALTIME
            clr         $FF9A                   * set border to black to indicate processing finished
 ENDC
            jmp         mainloop

*           The stack grows downwards from $4000
*           We should save at least 64 bytes for the stack
            rmb        $3FC0-*                  * throw an error if Primary code page overflowed

***********************************************************
*           The game directories and dynamic heap are stored in the first page of BASIC memory
*           we need to store and retain the first $E00 bytes for compatibility with Disk BASIC
*           routines (and other DOSes which may be loaded here in RAM)

*           Note that this section ($0E00-$1FFF) will get relocated in the BIN file after
*           assembly so that it is loaded at $4000 to avoid interfering with BASIC.  It will
*           be moved to its final place it $0E00 after DynoSprite starts, in MemMgr_MoveCode

            org         $0E00
 IFNDEF PASS
  ERROR Missing PASS definition!
 ELSE
  IFEQ PASS-1
            * empty game directories
Gamedir_Tiles
Gamedir_Objects
Gamedir_Levels
Gamedir_Sounds
Gamedir_Images
  ELSE
   IFEQ PASS-2
            * include game directories from auto-generated files
            include     gamedir-tiles.asm
            include     gamedir-objects.asm
            include     gamedir-levels.asm
            include     gamedir-sounds.asm
            include     gamedir-images.asm
   ELSE
    ERROR Invalid PASS definition!
   ENDC
  ENDC
 ENDC
HeapStartAddress        EQU     *

***********************************************************
*           The secondary code page is located in the last page of memory ($E000-$FFFF)

*           Note that this section ($E000-$FFFF) will get relocated in the BIN file after
*           assembly so that it is loaded at $6000 to avoid interfering with BASIC.  It will
*           be remapped to its final place it $E000 after DynoSprite starts, in MemMgr_MoveCode


            org         $E000
 IFEQ CPU-6309
            include     graphics-blockdraw-6309.asm
 ELSE
            include     graphics-blockdraw-6809.asm
 ENDC
            include     graphics-bkgrnd.asm
            include     graphics-image.asm
            include     graphics-text.asm
            include     disk.asm
            include     decompress.asm

 IFGT *-$FE00
    Error "In main.asm: Secondary code page ($E000-FDFF) is too big!"
 ENDC

***********************************************************
*           Postlog: auto-execution

            org         $0176
            jmp         start

            end         start

