*********************************************************************************
* DynoSprite - graphics-bkgrnd.asm
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

* Conceptually, the background pixel data occupy a large buffer block in the
* 512k Coco 3 memory space, called the Graphics Aperature.  The location of
* this aperature changes as the screen is scrolled.  We use the 256-byte per
* line video mode.  The graphics aperature contains 4 screen buffers, which
* are grouped into two pairs.  Each pair conists of an Even buffer followed
* (7 8k pages later) by an Odd buffer.  The background pixel data stored in
* the odd pair is offset by one byte from the data stored in the even pair.
* This allows us to scroll in 1-byte increments, by selecting either the Even
* or Odd buffer to draw the sprites on and display the frame.  This would
* otherwise not be possible, because the GIME has a 2-byte (4 pixel)
* granularity for setting the screen start address.  The two pairs are used
* for double buffering.  At any given time during the gameplay, one buffer
* pair is currently being sent to the monitor by the Coco's video output (the
* Front buffer pair), while the other pair is being erased and re-drawn in
* preparation for the next video frame to display.

***********************************************************
* Gfx_InitBkgrndBounds:
*
* - IN:
* - OUT:
* - Trashed: A,B
***********************************************************
Gfx_InitBkgrndBounds
            * calculate the maximum X,Y starting coordinates
            ldd         <Gfx_BkgrndMapWidth
            std         RC_leau_bkgrndMapWidth1+2   * save map width in code for RedrawColumn Y block iteration
            std         RC_leau_bkgrndMapWidth2+2   * save map width in code for RedrawColumn Y block iteration
            lslb
            rola
            lslb
            rola
            lslb
            rola                                * 8 bytes per block X
            subd        #160
            std         <Gfx_BkgrndStartXMax
            ldd         <Gfx_BkgrndMapHeight
            lslb
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola                                * 16 rows per block Y
            subd        #200
            std         <Gfx_BkgrndStartYMax
            * clear the fraction counters
            clr         <Gfx_BkgrndXFrac
            clr         <Gfx_BkgrndYFrac
            rts

***********************************************************
* Gfx_GetVertStart:
*   This function gets the Vertical Start Offset value to set for the beginning of the given Buffer Pair
*
* - IN:      Y=$0 for Buffer Pair 0, or $3800 for Buffer Pair 1
*            X=#Gfx_BkgrndStartXYList + 4 * (Buffer Pair)
* - OUT:     Y=Vertical Start Offset value (512k physical address divided by 8)
*            X=pointer to X,Y values (16 bits) for this Buffer Pair in Gfx_BkgrndStartXYList table
* - Trashed: A,B
***********************************************************
Gfx_GetVertStart
            ldd         2,x                     * Buffer 0 Y
            * Rows are 256 bytes, so Y coordinates must be << 8 to calculate physical byte address
            * However, I want to calculate the address in units of 8 bytes, so I only << 5
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            ADD_D_TO_Y
            ldd         ,x                      * Buffer 0 X
            * divide X value by 8 (shift right by 3)
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb                                * Now D is X >> 3
            ADD_D_TO_Y
            rts

***********************************************************
* Gfx_SetInitial/MoveAperature:
*   These functions initialize or move the graphics aperature based
*   upon the Buffer 0 / Buffer 1 starting coordinates in Gfx_BkgrndStartXYList
*
* - IN:
* - OUT:
* - Trashed: A,B,X,Y,U
***********************************************************

Gfx_SetInitialAperature
            ldx         #Gfx_BkgrndStartXYList  * Starting address depends on Buffer Pair 0
            ldy         #0
            bsr         Gfx_GetVertStart
            sty         ldx_VertStartOffLo@+1   * store start offset for Buffer 0
            ldx         #Gfx_BkgrndStartXYList+4 * ending address depends upon Buffer Pair 1
            ldy         #$3800                  * (buffer pair 1 is 14 8k pages later)
            bsr         Gfx_GetVertStart
            leay        $37FF,y                 * point to last 8-block byte in graphics aperature
ldx_VertStartOffLo@
            ldx         #0                      * SMC: get the starting offset
            jmp         MemMgr_InitializeGfxAperature

Gfx_MoveAperature
            ldd         <Gfx_BkgrndStartXYList+2 * Buffer 0 Y
            * Rows are 256 bytes, so Y coordinates must be << 8 to calculate physical byte address
            * However, I want to calculate the address in units of 8 bytes, so I only << 5
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            tfr         d,x
            ldd         <Gfx_BkgrndStartXYList  * Buffer 0 X
            * divide X value by 8 (shift right by 3)
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb                                * Now D is X >> 3
            ADD_D_TO_X
            ldd         <Gfx_BkgrndStartXYList+6 * Buffer 1 Y
            * Rows are 256 bytes, so Y coordinates must be << 8 to calculate physical byte address
            * However, I want to calculate the address in units of 8 bytes, so I only << 5
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            aslb
            rola
            addd        #$3800+$37FF            * (buffer pair 1 is 14 8k pages later)
                                                * + point to last 8-block byte in graphics aperature
            tfr         d,y
            ldd         <Gfx_BkgrndStartXYList+4 * Buffer 1 X
            * divide X value by 8 (shift right by 3)
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb                                * Now D is X >> 3
            ADD_D_TO_Y
            jmp         MemMgr_MoveGfxAperature

***********************************************************
* Gfx_FillScreen:
*   This function fills the even-pixel offscreen buffer with a given byte value
*
* - IN:      A = byte value to store in offscreen buffer
* - OUT:     none
* - Trashed: B,X,Y
***********************************************************
Gfx_FillScreen_Front
            sta         <LoadClearByte@+1,PCR   * save the value to write
            clra
            clrb
            jsr         Gfx_GetPixelAddress_Front * OUT: A=page number, Y=offset
            bra         MapGfxWindow@
Gfx_FillScreen_Back
            sta         <LoadClearByte@+1,PCR   * save the value to write
            clra
            clrb
            jsr         Gfx_GetPixelAddress_Back * OUT: A=page number, Y=offset
MapGfxWindow@
            sta         $FFA2                   * map starting graphics pages to $4000-$7FFF
            inca
            sta         $FFA3
            pshs        a
            leax        $4000,y                 * X is pointer to screen data
            ldy         #200                    * Y is row counter
LoadClearByte@
            lda         #0                      * SMC: byte value to store is written in code above
ClearLoopRow@
            ldb         #160
ClearLoopCol@
            sta         ,x+
            decb
            bne         ClearLoopCol@
            leax        96,x
            cmpx        #$6000
            blo         >
            leax        -$2000,x
            puls        b
            stb         $FFA2
            incb
            stb         $FFA3
            pshs        b
!           leay        -1,y
            bne         ClearLoopRow@
            leas        1,s
            rts

***********************************************************
* Gfx_InitialScreenFill:
*   This function fills both screen buffer pairs with the background pixel data
*   and sets the GIME video start address to point to the newly drawn data
*
* - IN:      starting X,Y values for both buffer pairs must be set in Gfx_BkgrndStartXYList
* - OUT:     none
* - Trashed: A,B,X,Y,U
***********************************************************
Gfx_InitialScreenFill
            lda         #200
            sta         RR_RectRowsY
            ldb         <Gfx_RenderingFrameX4
            ldx         #Gfx_BkgrndStartXYList
            abx
            lda         #24                     * starting by planning to draw a rectangle 24 blocks by 200 lines
            sta         RR_RectBlocksX
            ldd         ,x                      * starting X byte value for buffer pair
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb                                * divide by 8 to get starting block #
            cmpd        #2
            blo         >
            subd        #2
            bra         BlockStartDone@
!           dec         RR_RectBlocksX
            cmpd        #1
            blo         >
            DECREMENT_D
            bra         BlockStartDone@
!           dec         RR_RectBlocksX
            * FIXME I also need to check for right boundary condition
BlockStartDone@
            std         RR_StartBlkX
            ldd         2,x
            std         RR_StartRowY
            jsr         Gfx_RedrawRect          * draw buffer pair
            rts

***********************************************************
* Gfx_UpdatePhyAddress:
*   This function updates the Gfx_BkgrndPhyAddrList (page,offset) pair for a given output video frame
*
* - IN:      X = #Gfx_BkgrndStartXYList + 4 * !(Gfx_LastRenderedFrame & 1)
* - OUT:     X = unchanged
* - Trashed: A,B,Y
***********************************************************
Gfx_UpdatePhyAddress
            ldd         2,x                     * D = new Y coordinate
            addb        ,x                      * add high byte of X screen origin coordinate
            adca        #0                      * D is now upper 16 bits of physical start address (low 8 bits in Gfx_BkgrndNewX+1)
            pshs        b
            lslb
            rola
            lslb
            rola
            lslb
            rola                                * A is now 8k page number for buffer pair 0
            cmpx        #Gfx_BkgrndStartXYList
            beq         >                       * if we are updating buffer pair 1
            adda        #14                     * then it is 14 pages down
!           leay        Gfx_BkgrndPhyAddrList-Gfx_BkgrndStartXYList,x
                                                * Y is location to store physical address for screen start of new buffer pair
            ldb         1,x                     * B is low 8 bits of new X coordinate
            bitb        #1
            beq         >                       * if starting X location is odd
            adda        #7                      * then we need to point to odd buffer in pair, which is 7 pages down
!           sta         ,y                      * store 8k page number
            puls        a
            anda        #$1f
            andb        #$fe
            std         1,y                     * D is offset in 8k page for screen start
            rts

***********************************************************
* Gfx_GetPixelAddress:
*
* - IN:      A=Y coordinate in rows (0-199)
*            B=X coordinate in bytes (pixel pairs, 0-159)
* - OUT:     A=page number, Y=offset
* - Trashed: A,B,X,Y
***********************************************************
*
Gfx_GetPixelAddress_Back
            addb        #48                     * byte offset to middle of 256-byte row
            tfr         d,y                     * Y is byte offset to desired pixel within the screen
            ldb         <Gfx_RenderingFrameX4
            bra         GetPixelAddress@
Gfx_GetPixelAddress_Front
            addb        #48                     * byte offset to middle of 256-byte row
            tfr         d,y                     * Y is byte offset to desired pixel within the screen
            ldb         <Gfx_DisplayedFrame
            andb        #1
            lslb
            lslb
GetPixelAddress@
            ldx         #Gfx_BkgrndPhyAddrList
            abx
            tfr         y,d
            addd        1,x
            pshs        a
            anda        #$1f
            tfr         d,y
            puls        a
            lsra
            lsra
            lsra
            lsra
            lsra
            adda        ,x
            rts

***********************************************************
* Gfx_UpdateBackground:
*
* - IN:
* - OUT:
* - Trashed: A,B,X,Y,U
***********************************************************
* Locals:
RowOffsetHead@  fcb     0,0,0
RowOffsetTable@ fcb     0,50,100,150,200,200,200,200
*
Gfx_UpdateBackground
            * update the base physical address (page,offset) of the screen origin for the new buffer pair
            ldb         <Gfx_RenderingFrameX4
            ldx         #Gfx_BkgrndStartXYList
            abx
            jsr         Gfx_UpdatePhyAddress
            * update the graphics aperature in memory
            jsr         Gfx_MoveAperature
            * now handle drawing any new top/bottom rows
            lda         #22
            sta         <RR_RectBlocksX         * we always draw 22*16 pixels horizontally in each new row
            ldd         <Gfx_BkgrndNewX         * begin the starting block # calculation
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            tfr         d,x                     * store the starting block X index in X temporarily
            ldd         <Gfx_BkgrndNewY
            subd        <Gfx_BkgrndRedrawOldY
            beq         NoVerticalScroll@
            bhi         DrawBottomRows@
DrawTopRows@
            negb
            stb         <RR_RectRowsY
            ldd         <Gfx_BkgrndNewY
            std         <RR_StartRowY
            leax        ,x                      * test starting X block index
            beq         DrawRows@               * start drawing here if X == 0
            ldb         <Gfx_BkgrndNewX+1
            andb        #6                      * otherwise test for alignment with block boundary
            bne         DrawRows@
            leax        -1,x                    * if aligned, we need to start drawing 1 block to left of screen
            bra         DrawRows@
DrawBottomRows@
            stb         <RR_RectRowsY
            ldd         <Gfx_BkgrndRedrawOldY
            addd        #200
            std         <RR_StartRowY
            leax        ,x                      * test starting X block index
            beq         DrawMinus1Block@        * start drawing here if X == 0
            leax        -1,x                    * when drawing bottom rows, we always draw one block to the left of
                                                * the block containing the first column of the screen
            tfr         x,d                     * get starting X block index in register D
            addd        #22
            cmpd        <Gfx_BkgrndMapWidth
            blo         DrawRows@
DrawMinus1Block@
            dec         <RR_RectBlocksX
DrawRows@
            stx         <RR_StartBlkX           * store the starting X block index
            jsr         Gfx_RedrawRect
NoVerticalScroll@
            * set up for horizontal scrolling (we draw columns of blocks for the horizontal scrolling)
            lda         <Gfx_BkgrndRedrawOldX+1
            anda        #$FE
            nega
            adda        <Gfx_BkgrndNewX+1
            asra
            sta         <gfx_DeltaXBlks
            bmi         DrawLeftCols@
DrawRightCols@
            * now handle drawing columns on the right
            * start by setting up the left-most column of the 2 to update
            ldd         <Gfx_BkgrndRedrawOldX   * begin the starting block # calculation
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            addd        #21                     * X index of left column for update
            cmpd        <Gfx_BkgrndMapWidth
            bhs         RightColsDone@
            std         <RR_StartBlkX
            ldx         <Gfx_BkgrndNewY         * assume we will start at top of new column
            ldy         #RowOffsetTable@
            lda         <Gfx_BkgrndRedrawOldX+1
            anda        #6
            beq         SaveRCol0StartRow@
            lsra
            ldx         <Gfx_BkgrndRedrawOldY
            leay        a,y                     * Y points to starting row (relative to screen top)
            ldb         ,y
            abx                                 * add unsigned row offset to starting row
SaveRCol0StartRow@
            stx         <RR_StartRowY
            * calculate the ending row for this column
            ldx         <Gfx_BkgrndNewY
            ldb         <gfx_DeltaXBlks
            leay        b,y                     * Y points to ending row (relative to screen top)
            ldb         ,y
            abx                                 * X is +1 after last row to draw
            tfr         x,d
            subd        <RR_StartRowY           * D is number of rows to draw in this column
            bls         DrawLeftCols@
            stb         <RR_RectRowsY
            pshs        y
            jsr         Gfx_RedrawColumn        * draw first column
            puls        y
            * now set up for right-most column to update
            cmpy        #RowOffsetTable@+4
            bls         RightColsDone@
            ldx         <Gfx_BkgrndNewY
            stx         <RR_StartRowY
            ldx         <RR_StartBlkX           * increment starting block X index
            leax        1,x
            cmpx        <Gfx_BkgrndMapWidth
            bhs         RightColsDone@
            stx         <RR_StartBlkX
            lda         <Gfx_BkgrndNewX+1
            anda        #6
            lsra
            ldy         #RowOffsetTable@
            ldb         a,y
            stb         <RR_RectRowsY
            jsr         Gfx_RedrawColumn        * draw second column
RightColsDone@
            tst         <gfx_DeltaXBlks
            bne         UpdateBackgroundDone@
DrawLeftCols@
            * now handle drawing columns on the left
            ldd         <Gfx_BkgrndRedrawOldX   * begin the starting block # calculation
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            cmpd        #0
            beq         LeftColsDone@           * left boundary condition for inside column
            DECREMENT_D
            std         <RR_StartBlkX
            ldy         #RowOffsetTable@
            lda         <Gfx_BkgrndRedrawOldX+1
            anda        #6
            beq         DrawOuterLeftCol@
            lsra
            ldx         <Gfx_BkgrndRedrawOldY
            leay        a,y                     * Y points to starting row (relative to screen top)
            ldb         ,y
            abx                                 * add unsigned row offset to ending row
            leau        ,x                      * save the ending row # in U
            * calculate the starting row for this column
            ldx         <Gfx_BkgrndNewY
            ldb         <gfx_DeltaXBlks
            ldb         b,y                     * Y points to starting row (relative to screen top, DeltaXBlks is negative or 0)
            abx                                 * X is starting row
            stx         <RR_StartRowY
            tfr         u,d                     * get ending row # in D
            subd        <RR_StartRowY           * D is number of rows to draw in this column
            bls         LeftColsDone@
            stb         <RR_RectRowsY
            jsr         Gfx_RedrawColumn        * draw first column
DrawOuterLeftCol@
            * now set up for left-most column to update
            lda         <Gfx_BkgrndRedrawOldX+1
            eora        <Gfx_BkgrndNewX+1
            anda        #8                      * if the old and new playfield positions are on the same 8-byte X block
            beq         LeftColsDone@           * then we don't need to draw the outermost left column
            ldx         <RR_StartBlkX           * decrement starting block X index
            beq         LeftColsDone@           * left boundary condition for outside column
            leax        -1,x
            stx         <RR_StartBlkX
            ldx         <Gfx_BkgrndNewY
            lda         <Gfx_BkgrndNewX+1
            anda        #6
            lsra
            ldy         #RowOffsetTable@
            ldb         a,y
            abx
            stx         <RR_StartRowY
            negb
            addb        #200
            stb         <RR_RectRowsY
            jsr         Gfx_RedrawColumn        * draw second column
LeftColsDone@
UpdateBackgroundDone@
            rts

***********************************************************
* Gfx_RedrawRect:
*   This function updates the display RAM in a new portion of the graphics aperature to draw
*   the background tiles in an area that was just uncovered due to scrolling.
*   The calling software must populate the RR_* global variables before calling this function.
*   These globals are not modified by this function.
*
* - IN:      none
* - OUT:     none
* - Trashed: A,B,X,Y,U
***********************************************************
DBRFuncs@       fdb     Draw1Row
                fdb     Draw2Rows
                fdb     Draw3Rows
                fdb     Draw4Rows
                fdb     Draw5Rows
                fdb     Draw6Rows
                fdb     Draw7Rows
                fdb     Draw8Rows
                fdb     Draw4PlusRows
                fdb     Draw4PlusRows
                fdb     Draw4PlusRows
                fdb     Draw4PlusRows
                fdb     Draw4PlusRows
                fdb     Draw4PlusRows
                fdb     Draw4PlusRows
                fdb     Draw16Rows
*
Gfx_RedrawRect
            * Select the buffer pair to draw into and get the base buffer pair physical offset
            * +6 is 48 bytes to account for 160-byte line centered in 256-byte row stride
            ldx         #6
            ldb         <Gfx_LastRenderedFrame
            andb        #1
            bne         >                       * if last pair was 1, then draw into 0
            ldx         #(14*8192/8)+6          * last pair was 0, so draw into 1
!           ldd         <RR_StartBlkX
            ADD_D_TO_X                          * physical X block start offset (8 bytes/block /8= 1/block)
            ldd         <RR_StartRowY           * physical Y row start offset   (256 bytes/row /8= 32/row)
            lslb                                * so shift left by 5
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola
            ADD_D_TO_X
            * now Y is our physical starting offset.  map the page to $6000 and calculate the logical pointer
            tfr         x,d
            lsra
            lsra
            sta         <rr_ScreenPage
            tfr         a,b
            incb
            std         $FFA3                   * map Even screen to $6000-$9FFF
            addd        #$0707
            std         $FFA5                   * map Odd screen to $A000-$DFFF
            tfr         x,d
            anda        #3                      * get low 10 bits of physical offset and multiply by 8 to get byte offset
            lslb
            rola
            lslb
            rola
            lslb
            rola
            adda        #$60
            pshs        d                       * save logical pointer to destination on stack
            * now calculate the tilemap variables
            lda         <RR_StartRowY+1
            anda        #15
            tfr         a,b
            lslb
            lslb
            lslb                                * texture data is 8 bytes/row
            stb         <rr_TexRowOffset        * byte offset in texture data to compensate for starting block row
            nega
            adda        #16                     * A is # of rows available for drawing in this block
            sta         <rr_RowsLeftInBlk
            ldd         <RR_StartRowY           * D is starting Y row to draw.  Divide by 16 to get block #
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            lsrb                                * never have more than about 1152 lines, so don't bother with A on last shift
            * multiply Y block index (which is now 8-bits) by tilemap width
            tfr         d,y
            lda         <Gfx_BkgrndMapWidth     * high byte
            mul
            stb         <rr_TempMulHi
            tfr         y,d
            lda         <Gfx_BkgrndMapWidth+1   * low byte
            mul
            adda        <rr_TempMulHi
            addd        <RR_StartBlkX           * D == tilemap index for starting block
            * calculate the tilemap page which contains this block and map it to $0000
            tfr         d,u
            lsra
            lsra
            lsra
            lsra
            lsra
            adda        #VH_BKMAP
            sta         <rr_TilemapPage
            ldx         #MemMgr_VirtualTable
            lda         a,x
            sta         $FFA0
            * calculate a pointer to the starting block in the tilemap
            tfr         u,d
            anda        #$1F
            tfr         d,u
            * invalidate the current texture page
            lda         #$FF
            sta         cmpa_TexturePage@+1
            * main loop for drawing the blocks
            puls        y                       * Y is logical pointer to destination screen buffer
            lda         <RR_RectRowsY
            sta         <rr_RowsLeftY
DrawBlockLoopY@
            lda         <RR_RectBlocksX         * Set up X loop counter
            sta         <rr_BlocksLeftX
            lda         <rr_RowsLeftInBlk       * calculate number of rows to draw from each block during X loop
            cmpa        <rr_RowsLeftY
            bls         >
            lda         <rr_RowsLeftY
!           sta         <rr_RowsToDraw
            lsla
            ldx         #DBRFuncs@-2
            ldx         a,x
            stx         jsr_DrawBlockRows@+1    * store block copy routine address in 'jsr' instruction below
            pshs        y                       * store destination pointer to simplify the row iteration
DrawBlockLoopX@
            * get current block texture index
            lda         ,u
            * calculate texture page for this block texture and remap to $4000 if necessary
            anda        #$C0
cmpa_TexturePage@
            cmpa        #0                      * SMC: texture page is written here before start of loop
            beq         >
            sta         cmpa_TexturePage@+1
            lsra
            lsra
            lsra
            lsra
            lsra
            lsra
            ldx         #MemMgr_VirtualTable+VH_BKTILES
            lda         a,x
            sta         $FFA2
            * calculate pointer to the texture data (128 bytes per block)
!           lda         ,u+
            anda        #$3F                    * 64 textures per page
            clrb
            lsra
            rorb
            adda        #$40
            addb        <rr_TexRowOffset        * this will never go over a 256-byte boundary
            tfr         d,x                     * X is logical pointer to texture source
            * copy the background texture data to screen buffers
            pshs        u,y,dp
            lda         <rr_RowsToDraw          * just in case we call Draw4PlusRows
jsr_DrawBlockRows@
            jsr         >$0000                  * SMC: jump target address is stored here from Y loop head code
            puls        u,y,dp
            * map a new tilemap page if necessary
            cmpu        #$2000
            blo         >
            leau        -$2000,u
            inc         <rr_TilemapPage
            lda         <rr_TilemapPage
            ldx         #MemMgr_VirtualTable
            lda         a,x
            sta         $FFA0
            * increment state and loop back for remaining blocks in this row
!           leay        8,y                     * 8 bytes (16 pixels) per block
            dec         <rr_BlocksLeftX
            bne         DrawBlockLoopX@
            * exit if we're done
            lda         <rr_RowsLeftY
            suba        <rr_RowsToDraw
            beq         DrawBlockEnd@
            * nope, we have more rows to draw
            sta         <rr_RowsLeftY
            * adjust row variables for new row
            clr         <rr_TexRowOffset
            lda         #16
            sta         <rr_RowsLeftInBlk
            * advance destination pointer and map new screen page if necessary
            puls        d
            adda        <rr_RowsToDraw          * 256 bytes/line
            tfr         d,y
            cmpy        #$8000
            blo         >
            leay        -$2000,y
            inc         <rr_ScreenPage
            lda         <rr_ScreenPage
            tfr         a,b
            incb
            std         $FFA3                   * map Even screen to $6000-$9FFF
            addd        #$0707
            std         $FFA5                   * map Odd screen to $A000-$DFFF
            * advance tilemap pointer and map new tilemap page if necessary
!           tfr         u,d
            subb        <RR_RectBlocksX
            sbca        #0
            addd        <Gfx_BkgrndMapWidth
            tfr         d,u
            cmpa        #$20
            lblo        DrawBlockLoopY@
            leau        -$2000,u
            inc         <rr_TilemapPage
            lda         <rr_TilemapPage
            ldx         #MemMgr_VirtualTable
            lda         a,x
            sta         $FFA0
            * loop back for remaining rows
            jmp         DrawBlockLoopY@
DrawBlockEnd@
            leas        2,s                     * skip the stacked destination pointer
            rts


***********************************************************
* Gfx_RedrawColumn:
*   This function updates the display RAM in a new portion of the graphics aperature to draw
*   the background tiles in an area that was just uncovered due to scrolling.
*   The calling software must populate the RR_* global variables before calling this function.
*   These globals are not modified by this function.
*
* - IN:      none
* - OUT:     none
* - Trashed: A,B,X,Y,U
***********************************************************
Gfx_RedrawColumn
            * Select the buffer pair to draw into and get the base buffer pair physical offset
            * +6 is 48 bytes to account for 160-byte line centered in 256-byte row stride
            ldx         #6
            ldb         <Gfx_LastRenderedFrame
            andb        #1
            bne         >                       * if last pair was 1, then draw into 0
            ldx         #(14*8192/8)+6          * last pair was 0, so draw into 1
!           ldd         <RR_StartBlkX
            ADD_D_TO_X                          * physical X block start offset (8 bytes/block /8= 1/block)
            ldd         <RR_StartRowY           * physical Y row start offset   (256 bytes/row /8= 32/row)
            lslb                                * so shift left by 5
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola
            lslb
            rola
            ADD_D_TO_X
            * now Y is our physical starting offset.  map the page to $6000 and calculate the logical pointer
            tfr         x,d
            lsra
            lsra
            sta         <rr_ScreenPage
            tfr         a,b
            incb
            std         $FFA3                   * map Even screen to $6000-$9FFF
            addd        #$0707
            std         $FFA5                   * map Odd screen to $A000-$DFFF
            tfr         x,d
            anda        #3                      * get low 10 bits of physical offset and multiply by 8 to get byte offset
            lslb
            rola
            lslb
            rola
            lslb
            rola
            adda        #$60
            pshs        d                       * save logical pointer to destination on stack
            * now calculate the tilemap variables
            lda         <RR_StartRowY+1
            anda        #15
            tfr         a,b
            lslb
            lslb
            lslb                                * texture data is 8 bytes/row
            stb         <rr_TexRowOffset        * byte offset in texture data to compensate for starting block row
            nega
            adda        #16                     * A is # of rows available for drawing in this block
            sta         <rr_RowsLeftInBlk
            ldd         <RR_StartRowY           * D is starting Y row to draw.  Divide by 16 to get block #
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            lsrb                                * never have more than about 1152 lines, so don't both with A on last shift
            * multiply Y block index (which is now 8-bits) by tilemap width
            tfr         d,y
            lda         <Gfx_BkgrndMapWidth     * high byte
            mul
            stb         <rr_TempMulHi
            tfr         y,d
            lda         <Gfx_BkgrndMapWidth+1   * low byte
            mul
            adda        <rr_TempMulHi
            addd        <RR_StartBlkX           * D == tilemap index for starting block
            * calculate the tilemap page which contains this block and map it to $0000
            tfr         d,u
            lsra
            lsra
            lsra
            lsra
            lsra
            adda        #VH_BKMAP
            ldx         #MemMgr_VirtualTable
            sta         <rr_TilemapPage
            lda         a,x
            sta         $FFA0
            * calculate a pointer to the starting block in the tilemap
            tfr         u,d
            anda        #$1F
            tfr         d,u
            * invalidate the current texture page
            lda         #$FF
            sta         cmpa_TexturePage1@+1
            sta         cmpa_TexturePage2@+1
            * main loop for drawing the blocks
            puls        y                       * Y is logical pointer to destination screen buffer
            lda         <RR_RectRowsY
            sta         <rr_RowsLeftY
            lda         <rr_RowsLeftInBlk        * calculate number of rows to draw from each block during X loop
            cmpa        <rr_RowsLeftY
            bls         >
            lda         <rr_RowsLeftY
DrawBlockLoopY_Partial@
!           sta         <rr_RowsToDraw
            * get current block texture index
            lda         ,u
            * calculate texture page for this block texture and remap to $4000 if necessary
            anda        #$C0
cmpa_TexturePage1@
            cmpa        #0                      * SMC: texture page is written here before start of loop
            beq         >
            sta         cmpa_TexturePage1@+1
            sta         cmpa_TexturePage2@+1
            lsra
            lsra
            lsra
            lsra
            lsra
            lsra
            ldx         #MemMgr_VirtualTable+VH_BKTILES
            lda         a,x
            sta         $FFA2
            * calculate pointer to the texture data (128 bytes per block)
!           lda         ,u
            anda        #$3F                    * 64 textures per page
            clrb
            lsra
            rorb
            adda        #$40
            addb        <rr_TexRowOffset        * this will never go over a 256-byte boundary
            tfr         d,x                     * X is logical pointer to texture source
            * copy the background texture data to screen buffers
            pshs        u,y,dp
            lda         <rr_RowsToDraw
            jsr         Gfx_DrawBlockRows
            puls        u,y,dp
            * exit if we're done
            lda         <rr_RowsLeftY
            suba        <rr_RowsToDraw
            bne         >
            rts
!           sta         <rr_RowsLeftY           * nope, we have more rows to draw
            * advance destination pointer and map new screen page if necessary
            tfr         y,d
            adda        <rr_RowsToDraw          * 256 bytes/line
            tfr         d,y
            cmpa        #$80
            blo         >
            leay        -$2000,y
            inc         <rr_ScreenPage
            lda         <rr_ScreenPage
            tfr         a,b
            incb
            std         $FFA3                   * map Even screen to $6000-$9FFF
            addd        #$0707
            std         $FFA5                   * map Odd screen to $A000-$DFFF
            * advance tilemap pointer and map new tilemap page if necessary
RC_leau_bkgrndMapWidth1
!           leau        $7fff,u                 * SMC: this gets filled with Gfx_BkgrndMapWidth in Gfx_InitBkgrndBounds
            cmpu        #$2000
            blo         >
            leau        -$2000,u
            inc         <rr_TilemapPage
            lda         <rr_TilemapPage
            ldx         #MemMgr_VirtualTable
            lda         a,x
            sta         $FFA0
            * is there only a partial block remaining?
!           lda         <rr_RowsLeftY
            cmpa        #15
            bhi         DrawBlockLoopY_Full@
            clr         <rr_TexRowOffset        * set TexRowOffset to 0 for subsequent blocks (we will always start at top)
            bra         DrawBlockLoopY_Partial@
            * now we will draw full (16-row) blocks
DrawBlockLoopY_Full@
            * get current block texture index
            lda         ,u
            * calculate texture page for this block texture and remap to $4000 if necessary
            anda        #$C0
cmpa_TexturePage2@
            cmpa        #0                      * SMC: texture page is written here before start of loop
            beq         >
            sta         cmpa_TexturePage1@+1
            sta         cmpa_TexturePage2@+1
            lsra
            lsra
            lsra
            lsra
            lsra
            lsra
            ldx         #MemMgr_VirtualTable+VH_BKTILES
            lda         a,x
            sta         $FFA2
            * calculate pointer to the texture data (128 bytes per block)
!           lda         ,u
            anda        #$3F                    * 64 textures per page
            clrb
            lsra
            rorb
            adda        #$40
            tfr         d,x                     * X is logical pointer to texture source
            * copy the background texture data to screen buffers
            pshs        u,y,dp
            jsr         Draw16Rows
            puls        u,y,dp
            * exit if we're done
            lda         <rr_RowsLeftY
            suba        #16
            bne         >
            rts
!           sta         <rr_RowsLeftY           * nope, we have more rows to draw
            * advance destination pointer and map new screen page if necessary
            leay        4096,y                  * 16 lines * 256 bytes/line
            cmpy        #$8000
            blo         >
            leay        -$2000,y
            inc         <rr_ScreenPage
            lda         <rr_ScreenPage
            tfr         a,b
            incb
            std         $FFA3                   * map Even screen to $6000-$9FFF
            addd        #$0707
            std         $FFA5                   * map Odd screen to $A000-$DFFF
            * advance tilemap pointer and map new tilemap page if necessary
RC_leau_bkgrndMapWidth2
!           leau        $7fff,u                 * SMC: this gets filled with Gfx_BkgrndMapWidth in Gfx_InitBkgrndBounds
            cmpu        #$2000
            blo         >
            leau        -$2000,u
            inc         <rr_TilemapPage
            lda         <rr_TilemapPage
            ldx         #MemMgr_VirtualTable
            lda         a,x
            sta         $FFA0
            * jump to  back for remaining rows
!           lda         <rr_RowsLeftY           * how many rows are left?
            cmpa        #15
            bhi         DrawBlockLoopY_Full@
            clr         <rr_TexRowOffset        * set TexRowOffset to 0 for subsequent blocks (we will always start at top)
            jmp         DrawBlockLoopY_Partial@

***********************************************************
* Gfx_CollisionTestPoint:
*   This function takes an X,Y global coordinate relative to the background map, and finds the Collision Mask
*   value from the collision mask tile at that location. This is used to handle background collisions with objects
*   moving on the playfield.
*
* - IN:      X = global X coordinate
*            Y = global Y coordinate
* - OUT:     A = collision mask value (0-15) at the given input location
*                bit 3 = cannot move down
*                bit 2 = cannot move up
*                bit 1 = cannot move right
*                bit 0 = cannot move left
* - Trashed: A,B,X,Y
***********************************************************
Gfx_CollisionTestPoint
            pshs        y,x                     * save input coordinates
            tfr         y,d                     * D is Y coordinate (maximum value should be 1087, 68*16-1)
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            lsrb                                * B is Y block index (0-67)
            stb         <MultYLow@+1,PCR
 IFDEF DEBUG
            cmpd        <Gfx_BkgrndMapHeight
            blo         >
            swi                                 * Error: input Y coordinate is outside of tilemap bounds
 ENDC
            * do 16x8 multiply of Y block index with Map Width
!           lda         <Gfx_BkgrndMapWidth
            mul
            stb         <AddHighByte@+1,PCR
MultYLow@
            ldb         #0                      * SMC: load Y block index (0-67)
            lda         <Gfx_BkgrndMapWidth+1
            mul
AddHighByte@
            adda        #0                      * SMC: D is Y block index * Map Width
            std         <SumBlockMapIdx@+1,PCR
            tfr         x,d                     * D is X coordinate (maximum value is 32,000-1)
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb
            lsra
            rorb                                * D is X block index (0-2047)
 IFDEF DEBUG
            cmpd        <Gfx_BkgrndMapWidth
            blo         >
            swi                                 * Error: input X coordinate is outside of tilemap bounds
 ENDC
SumBlockMapIdx@
!           addd        #0                      * SMC: D is Final BlockMap Index (Y * MapWidth + X)
            std         <LoadTileBlockIdx@+1,PCR
            lsra                                * get page number in the background tilemap
            lsra
            lsra
            lsra
            lsra
            adda        #VH_BKMAP               * A is virtual handle of backgroup tilemap page to map into $8000
            ldb         #4
            jsr         MemMgr_MapBlock
LoadTileBlockIdx@
            ldd         #0                      * SMC: D is Final BlockMap Index (Y * MapWidth + X)
            anda        #$1F                    * D is page offset into tilemap ($0000-$1FFF)
            ora         #$80                    * D is memory address of tile block to read
            tfr         d,x
            lda         ,x                      * A is the block index of the tile block at the given location (0-254)
 IFDEF DEBUG
            cmpa        <Gfx_BkgrndBlockCount
            blo         >
            swi                                 * Error: Tile index from tilemap is greater than number of tile textures
 ENDC
!           ldx         <Gfx_CollisionTablePtr  * X is pointer to collision table in the heap
            lda         a,x                     * A is the Collision Table value for this background tile (0 is empty, 255 is solid)
            bne         NotEmpty@
            leas        4,s                     * pop input coordinates from stack
            rts                                 * tile is empty, collision mask is already 0
NotEmpty@
            cmpa        #255
            bne         NotSolid@
            lda         #15                     * tile is solid, load collision mask value of 15
            leas        4,s                     * pop input coordinates from stack
            rts
NotSolid@
            deca                                * A is an index into the collision tile array
 IFDEF DEBUG
            cmpa        <Gfx_BkgrndMaskCount
            blo     >
            swi                                 * Error: Tilemask index value in Collision Table is greater than number of mask textures
 ENDC
!           clrb
            adda        <Gfx_BkgrndBlockCount   * we need to add the total number of background tiles to get an index into the
            rora                                * complete tile array. The mask tiles come after the background tiles
            rorb                                * D is an index into the background tile data buffer (128 bytes per tile)
            std         <GetMaskDataAddr@+1,PCR
            lsra                                * get page number in the tile texture data buffer
            lsra
            lsra
            lsra
            lsra
            adda        #VH_BKTILES             * A is virtual handle of background tile texture page to map into $A000
            ldb         #5
            jsr         MemMgr_MapBlock
GetMaskDataAddr@
            ldd         #0                      * SMC: D is index into the background tile data buffer
            anda        #$1F                    * D is page offset into tile texture page ($0000-$1FFF)
            ora         #$A0                    * D is memory address of tile block to read
            tfr         d,x
            ldb         3,s                     * B is low byte of global Y coordinate
            andb        #15
            lslb
            lslb
            lslb                                * add 8 bytes per Y row in the block
            abx
            ldb         1,s                     * B is the low byte of the global X coordinate
            andb        #15
            lsrb                                * add 1 byte per two X columns in the block
            lda         b,x                     * A is the byte from the tilemask containing the selected point
            bcs         >
            lsra                                * global X coordinate is even, so desired mask value is in the high 4 bits
            lsra
            lsra
            lsra
!           anda        #15                     * A is the output collision mask value
            leas        4,s                     * pop input coordinates from stack
            rts
