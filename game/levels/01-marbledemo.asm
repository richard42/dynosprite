*********************************************************************************
* DynoSprite - game/levels/00-marbledemo.asm
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
* Note: The dynamic Level handling code is always loaded first in the level/object code page,
*       and this page is always mapped to $6000 when being accesssed in the DynoSprite core.
*       For this reason, you may use position-dependent instructions if desired for local data
*       and code.

* -----------------------------------------------------------------------------
* -- Type definitions only
* -----------------------------------------------------------------------------

            include     datastruct.asm
            include     dynosprite-symbols.asm

            org         $6000

* -----------------------------------------------------------------------------
* -- Initialization Functions for setting up demo
* -----------------------------------------------------------------------------

* Local data

Tetris01    fcb         0,0,0,1,1,1,2,1
Tetris02    fcb         0,1,1,1,2,1,2,0
Tetris03    fcb         0,0,1,0,0,1,1,1
Tetris04    fcb         1,0,0,1,1,1,2,1
Tetris05    fcb         1,0,2,0,0,1,1,1
Tetris06    fcb         0,0,1,0,1,1,2,1
Tetris07    fcb         0,0,1,0,2,0,3,0

***********************************************************
* Level_Initialize:
*
* - IN:      None
* - OUT:     None
* - Trashed: A,B,X,Y,U
***********************************************************

Level_Initialize
            * set the background map size to 256 x 64 blocks
            ldd         #256
            std         <Gfx_BkgrndMapWidth
            ldd         #64
            std         <Gfx_BkgrndMapHeight
            * we need to allocate one more page for the tilemap (total size 16k)
            lda         #2
            sta         <Gfx_BkgrndMapPages
            lda         #VH_BKMAP+1
            jsr         MemMgr_AllocateBlock
            * map the tilemap array to $8000-$BFFF
            ldb         #5
            jsr         MemMgr_MapBlock
            lda         #VH_BKMAP
            ldb         #4
            jsr         MemMgr_MapBlock
            * clear the map
            ldd         #0
            ldx         #$8000
!           std         ,x
            std         2,x
            std         4,x
            std         6,x
            leax        8,x
            cmpx        #$C000
            bne         <
            * draw an outline
            lda         #1
            ldx         #$8000
            clrb
!           sta         ,x+
            decb
            bne         <
            lda         #2
            leax        -1,x
!           sta         ,x
            leax        256,x
            incb
            cmpb        #63
            bne         <
            lda         #3
            leax        1,x
            clrb
!           sta         ,-x
            decb
            bne         <
            lda         #4
!           sta         ,x
            leax        -256,x
            incb
            cmpb        #64
            bne         <
            * Fill in the map with tetris blocks
            ldx         #750
BlockLoop@
            pshs        x
BlockTryX@
            * get random starting location
            jsr         Util_Random
            cmpa        #2
            blo         BlockTryX@
            cmpa        #253
            bhi         BlockTryX@
            pshs        a
BlockTryY@
            jsr         Util_Random
            anda        #63
            cmpa        #2
            blo         BlockTryY@
            cmpa        #61
            bhi         BlockTryY@
            puls        b
            addd        #$8000                  * now D is pointer to tilemap candidate location
            tfr         d,x
            * select random block type and orientation
!           jsr         Util_Random
            anda        #$7
            beq         <
            ldy         #Tetris01
            deca
            tfr         a,b
            lsrb
            incb
            pshs        b                       * B is color (1-4)
            lsla
            lsla
            lsla
            leay        a,y                     * Y is pointer to tetris block coordinates for selected piece type
            jsr         Util_Random
            anda        #3                      * A is orientation (0-3)
            puls        b
            pshs        a,b,x,y
            jsr         Piece_Test
            tsta
            bne         BlockGood@
            puls        a,b,x,y
            bra         BlockTryX@
BlockGood@
            puls        a,b,x,y
            jsr         Piece_Write
            puls        x
            leax        -1,x
            bne         BlockLoop@
            * all done
            rts

*           X = pointer to origin coordinate in tilemap for this candidate tetris piece
*           Y = pointer to 4 block coordinates (X,Y) which are always positive
*           A = orientation (0-3)
*           B = color (1-4)
*           Out: A=0 for fail, A=1 for pass
Piece_Test
            lsla
            ldu         #PTO_Table
            jmp         [a,u]

PTO_Table   fdb         TestO1,TestO2,TestO3,TestO4

TestO1      * +X, +Y
            ldb         ,y
            lda         1,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         2,y
            lda         3,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         4,y
            lda         5,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         6,y
            lda         7,y
            leau        d,x
            jsr         Block_Test
            beq         >
            rts
!           clra
            rts

TestO2      * -Y, +X
            ldb         1,y
            negb
            sex
            adda        ,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         3,y
            negb
            sex
            adda        2,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         5,y
            negb
            sex
            adda        4,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         7,y
            negb
            sex
            adda        6,y
            leau        d,x
            jsr         Block_Test
            beq         >
            rts
!           clra
            rts
            
TestO3      * -X, -Y
            ldb         ,y
            negb
            sex
            suba        1,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         2,y
            negb
            sex
            suba        3,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         4,y
            negb
            sex
            suba        5,y
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         6,y
            negb
            sex
            suba        7,y
            leau        d,x
            jsr         Block_Test
            beq         >
            rts
!           clra
            rts
            
TestO4      * +Y, -X
            ldb         1,y
            lda         ,y
            nega
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         3,y
            lda         2,y
            nega
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         5,y
            lda         4,y
            nega
            leau        d,x
            jsr         Block_Test
            beq         >
            ldb         7,y
            lda         6,y
            nega
            leau        d,x
            jsr         Block_Test
            beq         >
            rts
!           clra
            rts

Block_Test
            tst         -257,u
            bne         >
            tst         -256,u
            bne         >
            tst         -255,u
            bne         >
            tst         -1,u
            bne         >
            tst         ,u
            bne         >
            tst         1,u
            bne         >
            tst         255,u
            bne         >
            tst         256,u
            bne         >
            tst         257,u
            bne         >
            lda         #1
            rts
!           clra
            rts

Piece_Write
*           X = pointer to origin coordinate in tilemap for this candidate tetris piece
*           Y = pointer to 4 block coordinates (X,Y) which are always positive
*           A = orientation (0-3)
*           B = color (1-4)
            lsla
            ldu         #PWO_Table
            jmp         [a,u]

PWO_Table   fdb         WriteO1,WriteO2,WriteO3,WriteO4

WriteO1     * +X, +Y
            pshs        b
            ldb         ,y
            lda         1,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         2,y
            lda         3,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         4,y
            lda         5,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         6,y
            lda         7,y
            leau        d,x
            ldb         ,s
            stb         ,u
            leas        1,s
            rts

WriteO2     * -Y, +X
            pshs        b
            ldb         1,y
            negb
            sex
            adda        ,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         3,y
            negb
            sex
            adda        2,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         5,y
            negb
            sex
            adda        4,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         7,y
            negb
            sex
            adda        6,y
            leau        d,x
            ldb         ,s
            stb         ,u
            leas        1,s
            rts
            
WriteO3     * -X, -Y
            pshs        b
            ldd         #0
            subb        ,y
            sbca        1,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldd         #0
            subb        2,y
            sbca        3,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldd         #0
            subb        4,y
            sbca        5,y
            leau        d,x
            ldb         ,s
            stb         ,u
            ldd         #0
            subb        6,y
            sbca        7,y
            leau        d,x
            ldb         ,s
            stb         ,u
            leas        1,s
            rts
            
WriteO4     * +Y, -X
            pshs        b
            ldb         1,y
            lda         ,y
            nega
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         3,y
            lda         2,y
            nega
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         5,y
            lda         4,y
            nega
            leau        d,x
            ldb         ,s
            stb         ,u
            ldb         7,y
            lda         6,y
            nega
            leau        d,x
            ldb         ,s
            stb         ,u
            leas        1,s
            rts

***********************************************************
* Level_CalculateBkgrndNewXY:
*
* - IN:      None
* - OUT:     None
* - Trashed: A,B,X,U
***********************************************************
* This function evaluates the joystick position and calculates a
* new background X/Y starting location for the next frame.  It
* uses 8 bits of fractional position in each dimension to 
* give a smooth range of speeds

AccelFactor EQU         50
DecelFactor EQU         25
MaxSpeed    EQU         512

Level_CalculateBkgrndNewXY
            * reload level on button press
            lda         <Input_Buttons
            anda        #Joy1Button1
            bne         >
            lda         #1
            jmp         Ldr_Jump_To_New_Level
            *    update X coordinate based on joystick
!           ldx         <Gfx_BkgrndNewX         * get X coordinate of last rendered frame
            stx         <Gfx_BkgrndLastX
            ldb         <Input_JoystickX        * start by handling X direction scrolling
            cmpb        #16
            blo         XLeft@
            cmpb        #48
            bhi         XRight@
XCenter@
            ldd         <Demo_ScreenDeltaX88
            beq         XDone@
            blt         XCenter1@
            subd        #DecelFactor            * decelerate
            bgt         XDone@
            clra
            clrb
            bra         XDone@
XCenter1@
            addd        #DecelFactor            * decelerate
            blt         XDone@
            clra
            clrb
            bra         XDone@
XLeft@
            ldd         <Demo_ScreenDeltaX88
            ble         >
            clra
            clrb
            bra         XDone@
!           subd        #AccelFactor            * accelerate to the left
            cmpd        #-MaxSpeed
            bge         XDone@
            ldd         #-MaxSpeed
            bra         XDone@
XRight@
            ldd         <Demo_ScreenDeltaX88
            bge         >
            clra
            clrb
            bra         XDone@
!           addd        #AccelFactor            * accelerate to the right
            cmpd        #MaxSpeed
            ble         XDone@
            ldd         #MaxSpeed
XDone@
            std         <Demo_ScreenDeltaX88
            * multiply the position delta if we skipped a frame
            tst         <Obj_MotionFactor
            bmi         MotionXDone@            * D = 1X
            bne         >
            lslb
            rola
            bra         MotionXDone@            * D = 2X
!           lslb
            rola
            addd        <Demo_ScreenDeltaX88    * D = 3X
MotionXDone@
            addb        <Gfx_BkgrndXFrac
            adca        #0
            stb         <Gfx_BkgrndXFrac
            leax        a,x
            stx         <Gfx_BkgrndNewX         * store X coordinate for new frame to render
            ldx         <Gfx_BkgrndNewY         * get Y coordinate of last rendered frame
            stx         <Gfx_BkgrndLastY
            ldb         <Input_JoystickY
            cmpb        #16
            blo         YUp@
            cmpb        #48
            bhi         YDown@
YCenter@
            ldd         <Demo_ScreenDeltaY88
            beq         YDone@
            blt         YCenter1@
            subd        #DecelFactor            * decelerate
            bgt         YDone@
            clra
            clrb
            bra         YDone@
YCenter1@
            addd        #DecelFactor            * decelerate
            blt         YDone@
            clra
            clrb
            bra         YDone@
YUp@
            ldd         <Demo_ScreenDeltaY88
            ble         >
            clra
            clrb
            bra         YDone@
!           subd        #AccelFactor            * accelerate up
            cmpd        #-MaxSpeed
            bge         YDone@
            ldd         #-MaxSpeed
            bra         YDone@
YDown@
            ldd         <Demo_ScreenDeltaY88
            bge         >
            clra
            clrb
            bra         YDone@
!           addd        #AccelFactor            * accelerate down
            cmpd        #MaxSpeed
            ble         YDone@
            ldd         #MaxSpeed
YDone@
            std         <Demo_ScreenDeltaY88
            * multiply the position delta if we skipped a frame
            tst         <Obj_MotionFactor
            bmi         MotionYDone@            * D = 1X
            bne         >
            lslb
            rola
            bra         MotionYDone@            * D = 2X
!           lslb
            rola
            addd        <Demo_ScreenDeltaY88    * D = 3X
MotionYDone@
            addb        <Gfx_BkgrndYFrac
            adca        #0
            stb         <Gfx_BkgrndYFrac
            leax        a,x
            stx         <Gfx_BkgrndNewY         * store X coordinate for new frame to render
            rts


