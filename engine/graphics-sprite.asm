*********************************************************************************
* DynoSprite - graphics-sprite.asm
* Copyright (c) 2013, Richard Goedeken
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
* Gfx_SpriteInit:
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: A,B,X,Y
***********************************************************

Gfx_SpriteInit
            lda         #VH_SPRERASE            * start by allocating block to store background pixels for erasing
            jsr         MemMgr_AllocateBlock
            ldd         #$C000                  * initialize the erase data (Start,End) pointers
            std         <Gfx_SpriteErasePtrs
            std         <Gfx_SpriteErasePtrs+2
            ldd         #$D000
            std         <Gfx_SpriteErasePtrs+4
            std         <Gfx_SpriteErasePtrs+6
            rts

***********************************************************
* Gfx_SpriteUninit:
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: A,B,X,Y
***********************************************************

Gfx_SpriteUninit
            lda         #VH_SPRERASE
            jsr         MemMgr_FreeBlock
            rts

***********************************************************
* Gfx_SpriteEraseOffscreen:
*   This function erases all sprites which were previously drawn into the
*   frame buffer pair which is currently offscreen
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: A,B,X,Y,U
***********************************************************
*
Gfx_SpriteEraseOffscreen
            lda         <MemMgr_VirtualTable+VH_BASIC0  * map the BASIC0 block with heap into 6809 address space at $0000
            sta         $FFA0                   * this contains object tables
            lda         <MemMgr_VirtualTable+VH_SPRERASE
            sta         $FFA6                   * Map sprite erase data to $C000
            ldb         <Gfx_RenderingFrameX4
            ldx         #Gfx_SpriteErasePtrs
            abx
            ldy         ,x                      * Y is the starting point of erase buffer
            sty         EraseLoop@+2
            ldu         2,x                     * U is the top of the erase heap
            sty         2,x                     * reset heap ending pointer to beginning of heap
EraseLoop@
            cmpu        #0                      * SMC: immediate value to compare is written above
            bhi         EraseOne@
 IFDEF DEBUG
            beq         >
            swi                                 * error: we are not at the exact start of the heap
 ENDC
!           rts
EraseOne@
            lda         -1,u                    * A = sprite erase mode
            beq         >
            swi                                 * error: only No Rowcrop mode is currently supported
!           ldy         -3,u                    * Y = starting offset to restore bytes in graphics memory
            lda         -4,u                    * A = starting physical page # for graphics memory
            sta         $FFA3
            inca
            sta         $FFA4
            inca
            sta         $FFA5                   * screen window is mapped to $6000-$BFFF
            lda         -5,u                    * A = Code page (virtual handle) for erase function for this sprite
            ldx         #MemMgr_VirtualTable
            lda         a,x
            sta         $FFA2                   * code is at logical page starting at $4000
            tfr         u,d
            subd        #7
            subd        -7,u
            tfr         d,x                     * X is start of saved background pixel data
            leau        -2,x
            jsr         [,u]                    * call Erase function
            bra         EraseLoop@


***********************************************************
* Gfx_SpriteDrawSimple:
*   This function draws a sprite for an object which uses a single sprite without the rowcrop option
*   The sprite index to draw must be in the first byte of the object's state buffer
*
* - IN:      X = pointer to Current Object Table entry for object being drawn
*            U = pointer to Object Descriptor Table entry for object type being drawn
* - OUT:     N/A
* - Trashed: 
***********************************************************
Gfx_SpriteDrawSimple
            * calculate screen-relative Y coordinate to start drawing (DrawOffY = (SpriteGlobalY - Gfx_BkgrndNewY))
            ldd         COB.globalY,x
            subd        <Gfx_BkgrndNewY
 IFDEF DEBUG
            bhs         >
            swi                                 * error: negative screen Y coordinate
 ENDC
!           stb         <gfx_DrawOffsetY
            * calculate screen-relative X coordinate to start drawing (DrawOffX = (SpriteGlobalX >> 1) - Gfx_BkgrndNewX)
            ldd         COB.globalX,x
            lsra
            rorb
            subd        <Gfx_BkgrndNewX
            stb         <gfx_DrawOffsetX
            * get maximum number of sprites in this group
 IFDEF DEBUG
            lda         COB.groupIdx,x
            ldy         <Gfx_SpriteGroupsPtr
            ldb         <Gfx_NumSpriteGroups
!           cmpa        SGT.groupIdx,y
            beq         FoundSpriteGroup@
            leay        sizeof{SGT},y
            decb
            bne         <
            swi                                 * error: group index for current object not found
FoundSpriteGroup@
 ENDC
            * get pointer to Sprite Descriptor Table for current sprite
            lda         [COB.statePtr,x]        * sprite number must be first byte in state data
 IFDEF DEBUG
            cmpa        SGT.spCount,y
            bls         SpriteIdxOkay@
            swi                                 * error: sprite index is greater than number of sprites in group
SpriteIdxOkay@
 ENDC
            ldb         #sizeof{SDT}
            mul
            addd        COB.sprPtr,x
            tfr         d,u                     * now U points to SDT entry for sprite to draw
            * decide which function (left or right) to use (DrawLRParity = SpriteGlobalX & 1)
            tst         SDT.cpRight,u
            beq         DrawLeft@               * if there is no single pixel positioning, we must use the DrawLeft function
            ldb         COB.globalX+1,x
            andb        #1
            bne         DrawRight@
DrawLeft@
            lda         SDT.cpLeft,u
            ldb         #SDT.drawLeft
            bra         LRDone@
DrawRight@
            lda         SDT.cpRight,u
            ldb         #SDT.drawRight
LRDone@
            stb         <gfx_DrawLeftOrRight
            * map the code page which contains the drawing function
            ldy         #MemMgr_VirtualTable
            lda         a,y
            sta         $FFA2
            * calculate screen pointer offset to start drawing (DrawSrcOffset = ((DrawOffY + OffsetY) * 256) + DrawOffX + OffsetX
            ldb         <gfx_DrawOffsetX
            addb        SDT.offsetX,u
            lda         <gfx_DrawOffsetY
            adda        SDT.offsetY,u
            * finish calculating the page,offset pair where we will draw in physical memory
            addd        <Gfx_DrawScreenOffset    * must be between 0 and $1FFF
            sta         lda_ScreenOffset@+1
            anda        #$1F
            tfr         d,x                     * offset is in X
            leax        $6000,x                 * X is now pointer where we will write pixel data
lda_ScreenOffset@
            lda         #0                      * SMC: re-load high byte of screen offset
            lsra
            lsra
            lsra
            lsra
            lsra
            adda        <Gfx_DrawScreenPage     * page is in A
            * corner case: if starting offset is really close to the beginning of a page, we need to map the prior page as well,
            * because the draw/erase functions may load/store the first byte with an offset of up to -16 from the X register
            cmpx        #$6020
            bhs         >
            leax        $2000,x
            deca
 IFDEF DEBUG
            bpl         >
            swi                                 * error: starting page is first page
 ENDC
!           sta         <gfx_DrawSpritePage
            stx         <gfx_DrawSpriteOffset
            * screen window is mapped to $6000-$BFFF
            sta         $FFA3
            inca
            sta         $FFA4
            inca
            sta         $FFA5
            * set up Erase buffer stack data, and call Draw function
            ldy         <Gfx_SpriteErasePtrPtr
            ldy         2,y
            ldd         SDT.erase,u
            std         ,y++                    * store pointer to erase function before the background pixels
            pshs        u,y
            lda         <gfx_DrawLeftOrRight
            jsr         [a,u]                   * draw this sprite
            puls        u,y                     * restore pointers to Sprite Descriptor Table and erase data
            * finish writing Erase buffer stack data
            ldd         SDT.storeBytes,u
            ADD_D_TO_Y                          * Y is pointer to byte after newly written pixel restore data
            std         ,y                      * store (word) number of pixel restore bytes in this block
            lda         SDT.cpErase,u
            sta         2,y                     * store code page for erase function before the background pixels
            lda         <gfx_DrawSpritePage
            sta         3,y                     * store page where pixel data were stored
            ldd         <gfx_DrawSpriteOffset   * D is starting graphics memory pointer
            std         4,y
            clr         6,y                     * mode is 0 (no rowcrop)
            leay        7,y                     * now Y is pointer to end of sprite erase heap
            ldx         <Gfx_SpriteErasePtrPtr
            sty         2,x
 IFDEF DEBUG
            tfr         y,d
            subd        ,x                      * D is now size of sprite erase heap for this frame
            cmpa        #$10
            blo         >
            swi                                 * error, heap overflow
 ENDC
!           rts


***********************************************************
* Gfx_SpriteDrawRowcrop:
*   This function draws a sprite for an object which uses a single sprite with the rowcrop option
*   The sprite index to draw must be in the first byte of the object's state buffer
*   The starting row and ending row must be in the 2nd and 3rd bytes
*
* - IN:      X = pointer to Current Object Table entry for object being drawn
*            U = pointer to Object Descriptor Table entry for object type being drawn
* - OUT:     N/A
* - Trashed: 
***********************************************************

Gfx_SpriteDrawRowcrop
            swi                                 * error: not implemented yet

