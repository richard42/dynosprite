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

MapWidth    equ         800
MapHeight   equ         80

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
            * set the background map size to 800 x 80 blocks
            ldd         #MapWidth
            std         <Gfx_BkgrndMapWidth
            ldd         #MapHeight
            std         <Gfx_BkgrndMapHeight
            * the loader only allocates 1 page for the tilemap in this level
            * since we generate the map programmatically instead of loading it from disk,
            * we need to allocate seven more pages for the tilemap (total size 64k)
            lda         #8
            sta         <Gfx_BkgrndMapPages
            lda         #VH_BKMAP+1
AllocBlocksLoop@
            jsr         MemMgr_AllocateBlock
            inca
            cmpa        #VH_BKMAP+8
            bne         AllocBlocksLoop@
            * clear the map
            lda         #VH_BKMAP
ClearBlock@
            pshs        a
            ldb         #4
            jsr         MemMgr_MapBlock
            ldd         #0
            ldx         #$8000
!           std         ,x
            std         2,x
            std         4,x
            std         6,x
            leax        8,x
            cmpx        #$A000
            bne         <
            puls        a
            inca
            cmpa        #VH_BKMAP+8
            bne         ClearBlock@
            * draw an outline
            lda         #VH_BKMAP
            ldb         #4
            jsr         MemMgr_MapBlock
            lda         #1
            ldx         #$8000
            ldy         <Gfx_BkgrndMapWidth
!           sta         ,x+
            leay        -1,y
            bne         <
            ldb         #2
            leax        -1,x
            lda         #VH_BKMAP
            ldu         <Gfx_BkgrndMapWidth
            stu         <SMC_leaxY1@+2,PCR
            ldy         <Gfx_BkgrndMapHeight
OutlineYL1@
            stb         ,x
            leay        -1,y
            beq         EastWallDone@
SMC_leaxY1@
            leax        999,x                   * just use large number to force assembler to use 16-bit offset
            cmpx        #$A000
            blo         OutlineYL1@
            inca                                * advance to the next tilemap page
            leax        -$2000,x
            pshs        a,b,x
            ldb         #4
            jsr         MemMgr_MapBlock
            puls        a,b,x
            bra         OutlineYL1@
EastWallDone@
            lda         #VH_BKMAP
            ldb         #4
            jsr         MemMgr_MapBlock
            lda         #VH_BKMAP
            ldb         #3
            ldx         #$8000
            ldu         <Gfx_BkgrndMapWidth
            stu         <SMC_leaxY2@+2,PCR
            ldy         <Gfx_BkgrndMapHeight
OutlineYL2@
            stb         ,x
            leay        -1,y
            beq         WestWallDone@
SMC_leaxY2@
            leax        999,x                   * just use large number to force assembler to use 16-bit offset
            cmpx        #$A000
            blo         OutlineYL2@
            inca                                * advance to the next tilemap page
            leax        -$2000,x
            pshs        a,b,x
            ldb         #4
            jsr         MemMgr_MapBlock
            puls        a,b,x
            bra         OutlineYL2@
WestWallDone@
            inca                                * map in the next tilemap page in case we cross the boundary
            cmpa        #VH_BKMAP+8
            beq         >
            pshs        x
            ldb         #5
            jsr         MemMgr_MapBlock
            puls        x
!           ldb         #4
            ldy         <Gfx_BkgrndMapWidth
!           stb         ,x+
            leay        -1,y
            bne         <
            * debug fixme: reset the $8000-$DFFF logical space to the first 2 pages of tilemap space
            lda         #VH_BKMAP
            ldb         #4
            jsr         MemMgr_MapBlock
            lda         #VH_BKMAP+1
            ldb         #5
            jsr         MemMgr_MapBlock
            * Fill in the map with tetris blocks
            ldx         #2000
BlockLoop@
            pshs        x
BlockTryX@
            * get random starting location
            jsr         Util_Random
            ldb         <Gfx_BkgrndMapHeight+1  * height must be less than 256 blocks
            subb        #4
            mul
            adda        #2                      * A is random number between 2 and MapHeight-3
            pshs        a
            ldb         <Gfx_BkgrndMapWidth+1
            mul
            tfr         d,x
            puls        a
            ldb         <Gfx_BkgrndMapWidth
            mul
            tfr         b,a
            clrb
            leax        d,x                     * X is offset to random tilemap row
            ldd         <Gfx_BkgrndMapWidth
            subd        #4
            jsr         Util_RandomRange16
            addd        #2
            leax        d,x                     * X is offset to random tile in tilemap from (2,2) to (MaxX-3,MaxY-3)
            tfr         x,d
            anda        #$1F
            exg         x,d                     * X is page offset (0000-1fff)
            lsra
            lsra
            lsra
            lsra
            lsra                                * A is page number (0-7)
            adda        #VH_BKMAP
            cmpx        #$1000
            blo         LowerPageHalf@
            pshs        a,x
            ldb         #4
            jsr         MemMgr_MapBlock
            puls        a
            inca
            incb
            cmpa        #VH_BKMAP+8
            beq         >
            jsr         MemMgr_MapBlock
!           puls        x
            leax        $8000,x
            bra         PickBlockType@
LowerPageHalf@
            pshs        a,x
            ldb         #5
            jsr         MemMgr_MapBlock
            puls        a
            deca
            decb
            cmpa        #VH_BKMAP-1
            beq         >
            jsr         MemMgr_MapBlock
!           puls        x
            leax        $A000,x
PickBlockType@
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
            lbra         BlockTryX@
BlockGood@
            puls        a,b,x,y
            jsr         Piece_Write
            puls        x
            leax        -1,x
            lbne         BlockLoop@
            * all done
            rts

*           X = pointer to origin coordinate in tilemap for this candidate tetris piece
*           Y = pointer to 4 block coordinates (X,Y) which are always positive
*           A = orientation (0-3)
*           B = color (1-4)
*           Out: A=0 for fail, A=1 for pass
Piece_Test
            ldb         #4
            stb         PieceCounter
            lsla
            ldu         #PTO_Table
            jmp         [a,u]

PieceCounter fcb        0

PTO_Table   fdb         TestO1,TestO2,TestO3,TestO4

NegLines    fdb         0,-MapWidth,-MapWidth*2,-MapWidth*3
PosLines    fdb         0,MapWidth,MapWidth*2,MapWidth*3

TestO1      * +X, +Y
            ldu         #PosLines
            ldb         1,y
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y++
            leau        a,u
            jsr         Block_Test
            beq         >
            dec         PieceCounter
            bne         TestO1
!           rts

TestO2      * -Y, +X
            ldu         #NegLines
            ldb         ,y+
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y+
            leau        a,u
            jsr         Block_Test
            beq         >
            dec         PieceCounter
            bne         TestO2
!           rts
            
TestO3      * -X, -Y
            ldu         #NegLines
            ldb         1,y
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y++
            nega
            leau        a,u
            jsr         Block_Test
            beq         >
            dec         PieceCounter
            bne         TestO3
!           rts
            
TestO4      * +Y, -X
            ldu         #PosLines
            ldb         ,y+
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y+
            nega
            leau        a,u
            jsr         Block_Test
            beq         >
            dec         PieceCounter
            bne         TestO4
!           rts

Block_Test
            tst         -MapWidth-1,u
            bne         >
            tst         -MapWidth,u
            bne         >
            tst         -MapWidth+1,u
            bne         >
            tst         -1,u
            bne         >
            tst         ,u
            bne         >
            tst         1,u
            bne         >
            tst         MapWidth-1,u
            bne         >
            tst         MapWidth,u
            bne         >
            tst         MapWidth+1,u
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
            leau        a,u
            lda         #4
            sta         PieceCounter
            jmp         [,u]

PWO_Table   fdb         WriteO1,WriteO2,WriteO3,WriteO4

WriteO1     * +X, +Y
            pshs        b
!           ldu         #PosLines
            ldb         1,y
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y++
            leau        a,u
            ldb         ,s
            stb         ,u
            dec         PieceCounter
            bne         <
            puls        b
            rts

WriteO2     * -Y, +X
            pshs        b
!           ldu         #NegLines
            ldb         ,y+
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y+
            leau        a,u
            ldb         ,s
            stb         ,u
            dec         PieceCounter
            bne         <
            puls        b
            rts

WriteO3     * -X, -Y
            pshs        b
!           ldu         #NegLines
            ldb         1,y
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y++
            nega
            leau        a,u
            ldb         ,s
            stb         ,u
            dec         PieceCounter
            bne         <
            puls        b
            rts

WriteO4     * +Y, -X
            pshs        b
!           ldu         #PosLines
            ldb         ,y+
            lslb
            ldd         b,u
            leau        d,x
            lda         ,y+
            nega
            leau        a,u
            ldb         ,s
            stb         ,u
            dec         PieceCounter
            bne         <
            puls        b
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
            * pop the return address off the stack, because we will never return from this function
            leas        2,s
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


