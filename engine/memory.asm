*********************************************************************************
* DynoSprite - memory.asm
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

* There are 2 main groups of memory functionality provided by DynoSprite.
*
* First, there is a virtual memory subsystem which allows the engine to
* allocate 8k blocks of memory.  These memory blocks are referenced by their
* Virtual Handle.  They can be mapped into the 64k CPU memory space using this
* Virtual Handle.  This indirection is necessary because the virtual memory
* subsystem must automatically move the memory block in the 512k physical
* memory space whenever the graphics aperature moves over a memory block which
* is in use.
*
* Secondly, there is a Heap memory subsystem.  The Heap is located after the
* Game Data Directories in the BASIC0 page, and is used to store dynamic game
* data buffers as documented in the doc/AddressMap.txt file.  The Heap
* functionality provided here is fairly simple, in that it only allows
* allocation and freeing on an LIFO (Last-In First-Out) basis.

* Definitions
*
MAX_SPRITE_CODE_PAGES   EQU     25              * 64 - 28 (graphics aperture) - 6 (core code+rom) - 5 (min gfx+sound data)

* Virtual Handle definitions for 8k pages which are fixed at program start time
VH_CODE1        EQU     0                       * primary code page w/ stack, always resident at $2000
VH_CODE2        EQU     1                       * secondary code page, resident at $E000 except when calling DSKCON
VH_BASIC0       EQU     2                       * initial 3.5k BASIC data from first page, plus game directories and heap
                                                *   (used when calling DSKCON)
VH_BASICROM     EQU     3                       * Color BASIC code image (used when calling DSKCON for disk i/o)
VH_DSKROM       EQU     4                       * Disk BASIC code image (used when calling DSKCON for disk i/o)
VH_HIGHROM      EQU     5                       * Top 8k of cartridge ROM space (used with CoCoNET MicroSD Pak)

VH_SPRERASE     EQU     6                       * Sprite background pixels
VH_LVLOBJCODE   EQU     7                       * Level and object handling code page
VH_BKTILES      EQU     8                       * background block texture data (max 8 8k pages)
VH_BKMAP        EQU     16                      * background tilemap (max 8 8k pages)
VH_ZIPDATA      EQU     24                      * decompressor tables and large state data (one page)
VH_ZIPBUF       EQU     25                      * decompressed data buffer (max 5 8k pages)
VH_SOUNDDATA    EQU     30                      * audio waveform pages (max 8 8k pages)
VH_SPRCODE      EQU     38                      * sprite draw/erase code pages

***********************************************************
* MemMgr_Init
*   This function is called to set up the memory map after loading level data
*
* - IN:
* - OUT: 
* - Trashed: A, B, X, Y
***********************************************************

MemMgr_Init
            * start by setting all physical 8k blocks except the last 1 to $FF (free)
            * the last one will be set to $FE (fixed)
            ldx         #MemMgr_PhysicalMap
            lda         #$ff
            ldb         #63
!           sta         ,x+
            decb
            bne         <
            lda         #$fe
            sta         ,x
            * next, set all of the virtual table block handles to $ff (unused)
            ldx         #MemMgr_VirtualTable
            lda         #$ff
            ldb         #64
!           sta         ,x+
            decb
            bne         <
            * primary code and data occupies page $39, which is mapped by basic to $2000-$3FFF
            * so we want to mark this as the first used block in our virtual table (virtual handle 0)
            ldx         #MemMgr_PhysicalMap
            lda         #VH_CODE1
            sta         $39,x
            ldy         #MemMgr_VirtualTable
            lda         #$39
            sta         VH_CODE1,y
            * secondary code page is loaded at $6000 (page $3B), but will later be remapped to $E000
            lda         #VH_CODE2
            sta         $3B,x
            lda         #$3B
            sta         VH_CODE2,y
            * virtual handle 1: save the BASIC data in page $38 ($0000-$1FFF) for later disk access / ROM usage
            lda         #VH_BASIC0
            sta         $38,x
            lda         #$38
            sta         VH_BASIC0,y
            * virtual handle 2-4: save the ROM code pages in page $3D-$3FE ($A000-$FE00) for later disk access / ROM usage
            lda         #VH_BASICROM
            sta         $3D,x
            lda         #$3D
            sta         VH_BASICROM,y
            lda         #VH_DSKROM
            sta         $3E,x
            lda         #$3E
            sta         VH_DSKROM,y
            lda         #VH_HIGHROM
            sta         $3F,x
            lda         #$3F
            sta         VH_HIGHROM,y
            * initialize the heap
            ldd         #HeapStartAddress
            std         <MemMgr_HeapEndPtr
            rts


***********************************************************
* MemMgr_MoveCode
*   This function moves the code/data blocks (which were loaded at $4000 and $6000 to
*   avoid interfering with BASIC) to their final resting places at $0E00 and $E000
*
* - IN:
* - OUT: 
* - Trashed: A, B, X, Y, U
***********************************************************
MemMgr_MoveCode
            * Move the Game Directories first
            ldx         #$4000
            ldu         #$0E00
            ldd         #HeapStartAddress-$E00  * round length upwards to even number
            incb
            lsrb
            lslb
            tfr         d,y
MoveLoop1@
            ldd         ,x++
            std         ,u++
            leay        -2,y
            bne         MoveLoop1@
            * Then remap the secondary code page to $E000
            lda         <MemMgr_VirtualTable+VH_CODE2
            sta         $FFA7
            rts


***********************************************************
* MemMgr_Heap_Allocate
*   This function allocates a variable number of bytes from the heap storage block.
*
* - IN:      D = size of block to allocate
* - OUT:     X = starting address of new block, in heap, which is mapped from $0000-1FFF
* - Trashed: X,Y
***********************************************************

MemMgr_Heap_Allocate
 IFDEF DEBUG
            cmpd        #$2000                  * check requested buffer size
            blo         >
            swi                                 * don't be ridiculous, size of heap is only 8k
 ENDC
!           ldx         <MemMgr_HeapEndPtr      * calculate new heap ending address
            leay        4,x                     * we put the size before and after the block, so extend size by 4 bytes
            ADD_D_TO_Y                          * Y is the new ending address
 IFDEF DEBUG
            cmpy        #$2000
            blo         >
            swi                                 * error, heap is full
 ENDC
!           sty         <MemMgr_HeapEndPtr
            pshs        a
            lda         <MemMgr_VirtualTable+VH_BASIC0
            sta         $FFA0                   * map the BASIC0 block with the heap into 6809 address space at $0000
            puls        a
            std         ,x
            std         -2,y
            leax        2,x
            rts
            

***********************************************************
* MemMgr_Heap_FreeLast
*   This function de-allocates the buffer on the top of the heap.  Buffers must be free'd in
*   the reverse order in which they were allocated.
*
* - IN:      X = starting address of buffer to free
* - OUT:     
* - Trashed: D,X,Y
***********************************************************

MemMgr_Heap_FreeLast
            lda         <MemMgr_VirtualTable+VH_BASIC0
            sta         $FFA0                   * map the BASIC0 block with heap into 6809 address space at $0000
 IFDEF DEBUG
            ldd         -2,x                    * this should contain the size in bytes of the buffer to free
            leay        d,x                     * this should point to the ending size value
            cmpd        ,y
            beq         >
            swi                                 * error: memory corruption. size values before and after buffer don't match
!           leay        2,y                     * now Y should point to the heap end
            cmpy        <MemMgr_HeapEndPtr
            beq         >
            swi                                 * error: buffer to free is not the last one on the heap
 ENDC
!           leax        -2,x                    * X will be the new heap end
            stx         <MemMgr_HeapEndPtr
            rts

***********************************************************
* MemMgr_InitializeGfxAperature
*   This function sets the necessary blocks in the virtual table to $FD (graphics aperature),
*   moving any previously allocated blocks out of the way
*
* - IN:      X = Upper 16 (of 19) bits of lowest address of aperature
*            Y = Upper 16 (of 19) bits of highest address of aperature
* - OUT: 
* - Trashed: A,B,X,Y,U
***********************************************************

MemMgr_InitializeGfxAperature
            * convert the 16-bit addresses to 8k page numbers and store
            tfr         y,d
            lsra
            lsra
            sta         <MemMgr_GfxAperEnd
            tfr         x,d
            lsra
            lsra
            sta         <MemMgr_GfxAperStart
            * 1st pass: mark all of the physical blocks which are free, as being part of the graphics aperature
            ldx         #MemMgr_PhysicalMap
InitLoop1@
            ldb         a,x
            cmpb        #$ff
            bne         >
            ldb         #$fd                    * $FD = graphics aperature in physical map
            stb         a,x
!           inca
            cmpa        <MemMgr_GfxAperEnd
            bls         InitLoop1@
            * 2nd pass: relocate any blocks which are already allocated inside of the graphics aperature
            ldb         <MemMgr_GfxAperStart
InitLoop2@
            lda         b,x
            cmpa        #$fd
            beq         >
            pshs        b,x                     * A is virtual block handle to move
            ldb         #1                      * move this block to a high address
            jsr         MemMgr_MoveVirtualBlock
            lda         #$fd
            sta         b,y                     * mark old physical block as part of graphics aperature
            puls        b,x
!           incb
            cmpb        <MemMgr_GfxAperEnd
            bls         InitLoop2@
            rts


***********************************************************
* MemMgr_FreeGfxAperature
*   This function sets all virtual blocks which are mapped to
*   the graphics aperature ($fd) to Free instead ($ff)
*
* - IN:      N/A
* - OUT:     N/A
* - Trashed: A,B,X
***********************************************************

MemMgr_FreeGfxAperature
            ldx         #MemMgr_PhysicalMap
            clrb
FreeLoop@
            lda         b,x
            cmpa        #$fd
            bne         FreeLoopTail@
 IFDEF DEBUG
            cmpb        <MemMgr_GfxAperStart
            bhs         >
            swi                                 * Error: physical block marked with $fd before GfxAperStart
!           cmpb        <MemMgr_GfxAperEnd
            bls         >
            swi                                 * Error: physical block marked with $fd after GfxAperEnd
 ENDC
!           lda         #$ff
            sta         b,x
FreeLoopTail@
            incb
            cmpb        #64
            blo         FreeLoop@
            rts


***********************************************************
* MemMgr_AllocateBlock
* - IN:      A= Virtual block handle
* - OUT:     A= Virtual block handle
*            B= physical block number
*            X= #MemMgr_PhysicalMap
*            Y= #MemMgr_VirtualTable
* - Trashed: 
***********************************************************

MemMgr_AllocateBlock
            ldy         #MemMgr_VirtualTable    * check that the selected virtual handle is free
            ldb         a,y
            cmpb        #$ff
            beq         SearchHigh@
            swi                                 * error: virtual handle in use
SearchHigh@
            pshs        a
            ldx         #MemMgr_PhysicalMap
            ldb         #63
!           lda         b,x
            cmpa        #$ff
            beq         FoundBlock@
            decb
            bpl         <
            swi                                 * error, no unused physical blocks available
FoundBlock@
            * we have a free physical block index in B
            puls        a
            stb         a,y                     * store physical block # in virtual table
            sta         b,x                     * store virtual block handle in physical map
            rts

***********************************************************
* MemMgr_FreeBlock
* - IN:      A=virtual block handle to free
* - OUT:     
* - Trashed: A,B,X,Y
***********************************************************

MemMgr_FreeBlock
 IFDEF DEBUG
            cmpa        #64
            blo         >
            swi                                 * Error: invalid virtual handle number (greater than 63)
 ENDC
!           ldx         #MemMgr_VirtualTable
            ldy         #MemMgr_PhysicalMap
            ldb         a,x                     * B = physical block number
 IFDEF DEBUG
            cmpb        #64
            blo         >
            swi                                 * Error: invalid physical block # in virtual table
!           cmpa        b,y
            beq         >
            swi                                 * Error: physical/virtual tables out of sync
 ENDC
!           pshs        b
            ldb         #$ff
            stb         a,x                     * mark virtual handle as free
            puls        a
            stb         a,y                     * mark physical block as free
            rts

***********************************************************
* MemMgr_MapBlock
* - IN:      A = virtual block handle, B = 8k CPU block to map it to (0-7)
* - OUT:     A = physical block number, B = unchanged
* - Trashed: X
***********************************************************

MemMgr_MapBlock
 IFDEF DEBUG
            * check input conditions
            cmpb        #8
            blo         CPUBlockOkay@
            swi
CPUBlockOkay@
            cmpa        #64
            blo         VirtualIndexOkay@
            swi
VirtualIndexOkay@
 ENDC
            ldx         #MemMgr_VirtualTable
            lda         a,x                     * A is physical 512k block for this virtual block handle
 IFDEF DEBUG
            cmpa        #64
            blo         VirtualMapOkay@
            swi
VirtualMapOkay@
 ENDC
            ldx         #$FFA0                  * GIME MMU Task 0 base register
            abx
            sta         ,x                      * Map this physical block to the 6809 address space
            rts

***********************************************************
* MemMgr_CopyPhysicalBlock
* - IN:      A = source block number, B = destination block number
* - OUT: 
* - Trashed: A,B,X,Y,U,W
***********************************************************

MemMgr_CopyPhysicalBlock
 IFDEF DEBUG
            * check input conditions
            cmpa        #64
            blo         SrcBlkOkay@
            swi
SrcBlkOkay@
            cmpb        #64
            blo         DstBlkOkay@
            swi
DstBlkOkay@
 ENDC
 IFEQ CPU-6309
            ldu         $FFA5                   * mapped blocks for $A000 - $E000
            std         $FFA5
            ldx         #$A000
            ldy         #$C000
            ldw         #$2000
            tfm         x+,y+
            stu         $FFA5
            rts
 ELSE
            tfr         d,u
            lda         $FFA0
            ldb         $FFA5
            pshs        d
            tfr         u,d
            sta         $FFA0
            stb         $FFA5
            ldu         #$C000                  * 3
            ldy         #$2000                  * 4
CopyLoop@
            ldx         -2,y                    * 6
            ldd         -4,y                    * 6
            pshu        x,d                     * 9
            ldx         -6,y                    * 6
            ldd         -8,y                    * 6
            pshu        x,d                     * 9
            ldx         -10,y                   * 6
            ldd         -12,y                   * 6
            pshu        x,d                     * 9
            ldx         -14,y                   * 6
            ldd         -16,y                   * 6
            pshu        x,d                     * 9
            ldx         -18,y                   * 6
            ldd         -20,y                   * 6
            pshu        x,d                     * 9
            ldx         -22,y                   * 6
            ldd         -24,y                   * 6
            pshu        x,d                     * 9
            ldx         -26,y                   * 6
            ldd         -28,y                   * 6
            pshu        x,d                     * 9
            ldx         -30,y                   * 6
            ldd         -32,y                   * 6
            pshu        x,d                     * 9
            leay        -32,y                   * 5
            bne         CopyLoop@               * 3
            puls        d
            sta         $FFA0
            stb         $FFA5
            rts

 ENDIF

***********************************************************
* MemMgr_MoveVirtualBlock
*   This function finds an unused physical block (with preference for low or high blocks)
*   and then moves a virtual block into the free physical block.  It updates the virtual table
*   and the GIME MMU hardware.
*
* - IN:      A=Virtual block handle, B=(0 to prefer low physical address, != 0 to prefer high)
* - OUT:     B=Previous physical block #, Y=#MemMgr_PhysicalMap
* - Trashed: A,B,X,Y,U
***********************************************************
VirtHandle@     rmb     1
OldPhysBlk@     rmb     1
NewPhysBlk@     rmb     1
*
MemMgr_MoveVirtualBlock
            sta         VirtHandle@
            tstb
            bne         SearchHigh@
SearchLow@
            *clrb                               * don't need to clear because I already tested it for 0
            ldx         #MemMgr_PhysicalMap
!           lda         ,x
            cmpa        #$ff
            beq         FoundBlock@
            leax        1,x
            incb
            cmpb        #64
            bne         <
            swi                                 * error, no unused physical blocks available
SearchHigh@
            ldx         #MemMgr_PhysicalMap+64
            ldb         #63
!           lda         ,-x
            cmpa        #$ff
            beq         FoundBlock@
            decb
            bpl         <
            swi                                 * error, no unused physical blocks available
FoundBlock@
            * we have a free physical block index in B, and pointer to corresponding
            * physical map entry in X.
            * Step 1: allocate the new physical block to the virtual handle
            stb         NewPhysBlk@
            lda         VirtHandle@             * get the virtual block handle which is being moved
            sta         ,x                      * store this handle in the physical map
            * Step 2: copy the data from old to new physical block
            ldx         #MemMgr_VirtualTable
            leax        a,x
            lda         ,x                      * get the old physical block number
            sta         OldPhysBlk@
            pshs        x
            jsr         MemMgr_CopyPhysicalBlock    * copy the data to new physical block
            * Step 3: Verify that the old physical block was correctly mapped to this virtual handle
            ldy         #MemMgr_PhysicalMap
 IFDEF DEBUG
            lda         VirtHandle@
            ldb         OldPhysBlk@
            cmpa        b,y                     * verify that this physical block was mapped to virtual handle
            beq         PhysMapGood@
            swi                                 * error, virtual/physical table inconsistency
 ENDC
PhysMapGood@
            * Step 4: remap any logical (6809) blocks in MMU from old to new physical block
            lda         NewPhysBlk@
            ldx         #$FFA0
MMULoop@    ldb         ,x
            andb        #$3F
            cmpb        OldPhysBlk@
            bne         MMULoopTail@
            sta         ,x
MMULoopTail@
            leax        1,x
            cmpx        #$FFA8
            bne         MMULoop@
            * Step 5: remap virtual table from old physical block to new one
            puls        x
            sta         ,x
            * Step 6: Set the old physical block to 'free'
            lda         #$ff
            ldb         OldPhysBlk@
            sta         b,y
            rts

***********************************************************
* MemMgr_MoveGfxAperature
* - IN:      X = Upper 16 bits of lowest address of new aperature
*            Y = Upper 16 bits of highest address of new aperature
* - OUT: 
* - Trashed: A,B,X,Y,U
***********************************************************

MemMgr_MoveGfxAperature
            * convert the start 16-bit address to 8k page number and compare to previous value
            tfr         x,d
            lsra
            lsra
            suba        <MemMgr_GfxAperStart
            beq         CheckEndBlock@
            cmpa        #1
            beq         StartContract@
 IFDEF DEBUG
            cmpa        #-1
            beq         StartExpand@
            swi                                 * error, graphics aperature start point moved by more than 1 block
 ENDC
StartExpand@
            dec         <MemMgr_GfxAperStart    * decrement and load the starting block #
            ldb         <MemMgr_GfxAperStart
            ldx         #MemMgr_PhysicalMap
            abx                                 * get pointer to phys map entry for new block which we will commandeer
            lda         ,x                      * get previous map entry
            cmpa        #$ff
            beq         StartExpandTail@
 IFDEF DEBUG
            cmpa        #64
            blo         MoveTopBlock@
            swi                                 * error, we need this block but it is unmoveable
 ENDC
MoveTopBlock@                                   * virtual block handle is in A
            ldb         #1                      * look for a high physical block
            pshs        x,y
            jsr         MemMgr_MoveVirtualBlock
            puls        x,y
StartExpandTail@
            ldb         #$fd
            stb         ,x                      * set new map entry to "graphics aperature"
            bra         CheckEndBlock@
StartContract@
            lda         <MemMgr_GfxAperStart
            inc         <MemMgr_GfxAperStart
            ldx         #MemMgr_PhysicalMap
            ldb         #$ff
            stb         a,x                     * mark freed physical block in map
CheckEndBlock@
            tfr         y,d
            lsra
            lsra
            suba        <MemMgr_GfxAperEnd
            beq         Done@
            cmpa        #-1
            beq         EndContract@
 IFDEF DEBUG
            cmpa        #1
            beq         EndExpand@
            swi                                 * error, graphics aperature end point moved by more than 1 block
 ENDC
EndExpand@
            inc         <MemMgr_GfxAperEnd      * increment and load the ending block #
            ldb         <MemMgr_GfxAperEnd
            ldx         #MemMgr_PhysicalMap
            abx                                 * get pointer to phys map entry for new block which we will commandeer
            lda         ,x                      * get previous map entry
            cmpa        #$ff
            beq         EndExpandTail@
 IFDEF DEBUG
            cmpa        #64
            blo         MoveBottomBlock@
            swi                                 * error, we need this block but it is unmoveable
 ENDC
MoveBottomBlock@
            clrb                                * looking for a low physical block
            pshs        x
            jsr         MemMgr_MoveVirtualBlock
            puls        x
EndExpandTail@
            ldb         #$fd
            stb         ,x                      * set new block to "graphics aperature"
            rts
EndContract@
            lda         <MemMgr_GfxAperEnd
            dec         <MemMgr_GfxAperEnd
            ldx         #MemMgr_PhysicalMap
            ldb         #$ff
            stb         a,x                     * mark freed physical block in map
Done@
            rts


