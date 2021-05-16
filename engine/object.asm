*********************************************************************************
* DynoSprite - object.asm
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
* Obj_Init_CurrentObjectTable
*
* - IN:      X = starting address of Object Initialization Table
* - OUT:     None
* - Trashed: A,B,X,Y,U
***********************************************************

Obj_Init_CurrentObjectTable
            pshs        x
            tfr         x,u
            ldx         <Obj_CurrentTablePtr
            * create objects while calculating the number of bytes to reserve for object data
            ldd         #0
            pshs        d                       * push counter of number of bytes to reserve for object state
            lda         <Obj_NumCurrent
            bne         ObjectLoop1@
            puls        d,x
            rts                                 * no objects to initialize, just return
ObjectLoop1@
            pshs        a
            lda         ,u+                     * get group ID for this object
            sta         COB.groupIdx,x          * store in COB
            ldy         <Gfx_SpriteGroupsPtr    * search through sprite group table
            ldb         <Gfx_NumSpriteGroups
SearchForGroup@
            tstb                                * throw error if we have searched through all sprite groups
            bne         >
            swi
!           cmpa        SGT.groupIdx,y
            beq         FoundGroup@
            leay        sizeof{SGT},y
            decb
            bra         SearchForGroup@
FoundGroup@
            lda         ,u+                     * get ObjectID for this object
            sta         COB.objectIdx,x         * store in COB
            cmpa        SGT.obCount,y
            blo         >                       * throw an error if this object index does not exist in this group
            swi
!           lda         ,u+                     * active flags
            sta         COB.active,x
            ldd         ,u++
            std         COB.globalX,x
            ldd         ,u++
            std         COB.globalY,x
            ldd         SGT.sprites,y           * save pointer to sprite descriptor table for this group
            std         COB.sprPtr,x
            ldd         SGT.rowcrop,y           * save pointer to rowcrop table for this group
            std         COB.rowPtr,x
            lda         COB.objectIdx,x         * reload the object index
            ldy         SGT.objects,y
            ldb         #sizeof{ODT}
            mul
            ADD_D_TO_Y                          * y is pointer to object descriptor for this object
            sty         COB.odtPtr,x
            lda         ODT.initSize,y          * get number of initialization bytes for this object
            leau        a,u                     * skip over these bytes in object init stream (we will use them later)
            lda         ODT.dataSize,y          * get number of object state bytes for this object
            ldy         1,s                     * get count of object state data bytes reserved
            sty         COB.statePtr,x
            leay        a,y                     * increase counter by # of bytes to reserve for this object
            sty         1,s
            * 1st pass for this object is done, so go to next object
            leax        sizeof{COB},x
            puls        a
            deca
            bne         ObjectLoop1@
            * now we will reserve space for object state data
            puls        d                       * D is total number of bytes to reserve for object state
            jsr         MemMgr_Heap_Allocate
            stx         <Obj_StateDataPtr
            * finally, fix up the state data addresses with our buffer location and call the object initialization functions
            puls        u                       * get pointer to start of object initialization list
            ldx         <Obj_CurrentTablePtr    * X points to start of Current Object Table
            lda         <Obj_NumCurrent
ObjectLoop2@
            pshs        a
            ldd         COB.statePtr,x
            addd        <Obj_StateDataPtr
            std         COB.statePtr,x          * the state data pointer is now correct
            leau        7,u                     * point to the initialization data for this object in the object init stream
            ldy         COB.odtPtr,x
 IFNE       OBJPAGES-1
            lda         [ODT.vpageAddr,y]       * load the page number
            sta         $FFA3                   * load the page
 ENDC
            pshs        u,y,x
            jsr         [ODT.init,y]            * call the initialization function for this object type
            puls        x,y,u
            lda         ODT.initSize,y
            leau        a,u                     * point to next object in init stream
            leax        sizeof{COB},x
            puls        a
            deca
            bne         ObjectLoop2@
 IFNE       OBJPAGES-1
!           lda         <MemMgr_VirtualTable+VH_LVLOBJCODE1 * Map in the first page
            sta         $FFA3
 ENDC
            rts

***********************************************************
* Obj_Uninit_Objects
*
* - IN:      None
* - OUT:     None
* - Trashed: D,X,Y
***********************************************************

Obj_Uninit_Objects
            ldx         <Obj_StateDataPtr
            jsr         MemMgr_Heap_FreeLast
            rts


