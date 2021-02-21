#!/usr/bin/env python3
#********************************************************************************
# DynoSprite - scripts/sprite2asm.py
# Copyright (c) 2013-2014, Richard Goedeken
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#********************************************************************************

import re
import sys
import copy

# *************************************************************************************************
# Assembly language output classes
# *************************************************************************************************

class AsmMetrics:
    def __init__(self):
        self.cycles = 0
        self.bytes = 0

    def __add__(self, other):
        self.cycles += other.cycles
        self.bytes += other.bytes
        return self

regA = 1
regB = 2
regD = 3
regE = 4
regF = 8
regW = 12
regQ = 15
regX = 16
regY = 32
regU = 64
regS = 128
regName = { regA:"a", regB:"b", regD:"d", regE:"e", regF:"f", regW:"w", regQ:"q", regX:"x", regY:"y", regU:"u", regS:"s" }

class AsmRegisters:
    def __init__(self):
        self.valid = 0
        self.values = { }

    def Invalidate(self, regnum):
        self.valid &= ~regnum

    def SetValue(self, regnum, value):
        self.valid |= regnum
        if regnum == regD:
            self.values[regA] = value >> 8
            self.values[regB] = value & 0xff
        elif regnum == regW:
            self.values[regE] = value >> 8
            self.values[regF] = value & 0xff
        elif regnum == regQ:
            self.values[regA] = (value >> 24) & 0xff
            self.values[regB] = (value >> 16) & 0xff
            self.values[regE] = (value >> 8) & 0xff
            self.values[regF] = (value & 0xff)
        else:
            self.values[regnum] = value

    def GetValue(self, regnum):
        if regnum == regD:
            return ((self.values[regA] << 8) + self.values[regB])
        elif regnum == regW:
            return ((self.values[regE] << 8) + self.values[regF])
        elif regnum == regQ:
            return ((self.values[regA] << 24) + (self.values[regB] << 16) + (self.values[regE] << 8) + self.values[regF])
        else:
            return self.values[regnum]

    def IsValid(self, regnum):
        return bool((self.valid & regnum) == regnum)

class AsmStream:
    def __init__(self, name, regState=None):
        self.name = name
        if name == None:
            self.text = ""
        else:
            self.text = "*" * 60 + f"\n* {name}:\n" + "*" * 60 + f"\n{name}\n"
        self.metrics = AsmMetrics()
        if regState == None:
            self.reg = AsmRegisters()
        else:
            self.reg = regState

    def __add__(self, other):
        self.metrics += other.metrics
        self.text += other.text
        self.reg = other.reg
        return self

    def emit_comment(self, text):
        self.text += "            * " + text + "\n"

    def emit_label(self, text):
        self.text += f"{text}\n"

    def emit_op(self, op, reg, comment, cycles6809, cycles6309, bytes):
        # generate string for this instruction line
        str = "            " + op
        if reg != "":
            str += " " * (12 - len(op)) + reg
        if comment != "":
            str += " " * (24 - len(reg)) + "* " + comment
        str += "\n"
        # update member variables
        self.text += str
        if CPU == 6309:
            self.metrics.cycles += cycles6309
        else:
            self.metrics.cycles += cycles6809
        self.metrics.bytes += bytes

    def gen_loadimm_accum(self, regnum, value, comment):
        if self.reg.IsValid(regnum) and self.reg.GetValue(regnum) == value:
            # print("gen_loadimm_accum warning: register '%s' loading value 0x%x it already contains" % (regName[regnum], value))
            return
        # optimization: if possible, demote this accumulator load instruction to a smaller size
        if regnum == regQ and self.reg.IsValid(regD) and self.reg.GetValue(regD) == ((value >> 16) & 0xffff):
            regnum = regW
            value = value & 0xffff
        elif regnum == regQ and self.reg.IsValid(regW) and self.reg.GetValue(regW) == (value & 0xffff):
            regnum = regD
            value = value >> 16
        if regnum == regW and self.reg.IsValid(regE) and self.reg.GetValue(regE) == ((value >> 8) & 0xff):
            regnum = regF
            value = value & 0xff
        elif regnum == regW and self.reg.IsValid(regF) and self.reg.GetValue(regF) == (value & 0xff):
            regnum = regE
            value = value >> 8
        if regnum == regD and self.reg.IsValid(regA) and self.reg.GetValue(regA) == ((value >> 8) & 0xff):
            regnum = regB
            value = value & 0xff
        elif regnum == regD and self.reg.IsValid(regB) and self.reg.GetValue(regB) == (value & 0xff):
            regnum = regA
            value = value >> 8
        # handle register Q loads separately
        if regnum == regQ:
            self.emit_op("ldq", (f"#${value:08x}"), comment, 5, 5, 5)
            self.reg.SetValue(regQ, value)
            return
        # sanity check on register to load
        if regnum != regA and regnum != regB and regnum != regD and regnum != regE and regnum != regF and regnum != regW:
            raise Exception(f"invalid accumulator register '{regName[regnum]}' give to gen_loadimm_accum")
        # if we know the previous value of the register that we're loading, then we may be able to save some
        # bytes/cycles by modifying it with a clr/com/neg/inc/dec instruction instead of loading it
        if self.reg.IsValid(regnum):
            oldval = self.reg.GetValue(regnum)
        else:
            oldval = None
        if value == 0 and (regnum == regA or regnum == regB):
            self.emit_op(f"clr{regName[regnum]}", "", comment, 2, 1, 1)
        elif value == 0 and CPU == 6309 and (regnum == regD or regnum == regE or regnum == regF or regnum == regW):
            self.emit_op(f"clr{regName[regnum]}", "", comment, 3, 2, 2)
        elif oldval == 255 - value and (regnum == regA or regnum == regB):
            self.emit_op(f"com{regName[regnum]}", "", comment + f" ({regName[regnum]} = ~${oldval:02x} = ${value:02x})", 2, 1, 1)
        elif oldval == 255 - value and CPU == 6309 and (regnum == regE or regnum == regF):
            self.emit_op(f"com{regName[regnum]}", "", comment + f" ({regName[regnum]} = ~${oldval:02x} = ${value:02x})", 3, 2, 2)
        elif oldval == 65535 - value and CPU == 6309 and (regnum == regD or regnum == regW):
            self.emit_op(f"com{regName[regnum]}", "", comment + f" ({regName[regnum]} = ~${oldval:04x} = ${value:04x})", 3, 2, 2)
        elif oldval == (256 - value) & 0xff and (regnum == regA or regnum == regB):
            self.emit_op(f"neg{regName[regnum]}", "", comment + f" ({regName[regnum]} = -${oldval:02x} = ${value:02x})", 2, 1, 1)
        elif oldval == (65536 - value) & 0xffff and CPU == 6309 and regnum == regD:
            self.emit_op(f"neg{regName[regnum]}", "", comment + f" ({regName[regnum]} = -${oldval:04x} = ${value:04x})", 3, 2, 2)
        elif oldval == (value - 1) & 0xff and (regnum == regA or regnum == regB):
            self.emit_op(f"inc{regName[regnum]}", "", comment + f" ({regName[regnum]} = ${oldval:02x}+1 = ${value:02x})", 2, 1, 1)
        elif oldval == (value - 1) & 0xff and CPU == 6309 and (regnum == regE or regnum == regF):
            self.emit_op(f"inc{regName[regnum]}", "", comment + f" ({regName[regnum]} = ${oldval:02x}+1 = ${value:02x})", 3, 2, 2)
        elif oldval == (value - 1) & 0xffff and CPU == 6309 and (regnum == regD or regnum == regW):
            self.emit_op(f"inc{regName[regnum]}", "", comment + f" ({regName[regnum]} = ${oldval:04x}+1 = ${value:04x})", 3, 2, 2)
        elif oldval == (value + 1) & 0xff and (regnum == regA or regnum == regB):
            self.emit_op(f"dec{regName[regnum]}", "", comment + f" ({regName[regnum]} = ${oldval:02x}-1 = ${value:02x})", 2, 1, 1)
        elif oldval == (value + 1) & 0xff and CPU == 6309 and (regnum == regE or regnum == regF):
            self.emit_op(f"dec{regName[regnum]}", "", comment + f" ({regName[regnum]} = ${oldval:02x}-1 = ${value:02x})", 3, 2, 2)
        elif oldval == (value + 1) & 0xffff and CPU == 6309 and (regnum == regD or regnum == regW):
            self.emit_op(f"dec{regName[regnum]}", "", comment + f" ({regName[regnum]} = ${oldval:04x}-1 = ${value:04x})", 3, 2, 2)
        else:
            # we must do a full register load instruction
            if regnum == regD:
                self.emit_op("ldd", (f"#${value:04x}"), comment, 3, 3, 3)
            elif regnum == regW:
                self.emit_op("ldw", (f"#${value:04x}"), comment, 4, 4, 4)
            elif regnum == regE or regnum == regF:
                self.emit_op(f"ld{regName[regnum]}", (f"#${value:02x}"), comment, 3, 3, 3)
            else:
                self.emit_op(f"ld{regName[regnum]}", (f"#${value:02x}"), comment, 2, 2, 2)
        self.reg.SetValue(regnum, value)

    def gen_loadstore_indexed(self, bLoad, regLdSt, regIdx, offset, comment):
        opcode = "{}{}".format({False:"st",True:"ld"}[bLoad], regName[regLdSt])
        if offset == 0:
            operands = f",{regName[regIdx]}"
        else:
            operands = f"{int(offset)},{regName[regIdx]}"
        if regLdSt == regA or regLdSt == regB:
            cycles = 4
            bytes = 2
        elif regLdSt == regE or regLdSt == regF:
            cycles = 5
            bytes = 3
        elif regLdSt == regD or regLdSt == regU or regLdSt == regX:
            cycles = 5
            bytes = 2
        elif regLdSt == regS or regLdSt == regW or regLdSt == regY:
            cycles = 6
            bytes = 3
        elif regLdSt == regQ:
            cycles = 8
            bytes = 3
        else:
            raise Exception(f"Unsupported register {int(regLdSt)}")
        if offset == 0:
            cycles += 0
            bytes += 0
        elif offset < 16 and offset >= -16:
            cycles += 1
            bytes += 0
        elif offset < 128 and offset >= -128:
            cycles += 1
            bytes += 1
        else:
            if CPU == 6309:
                cycles += 3
            else:
                cycles += 4  # only 3 if 6309
            bytes += 2
        self.emit_op(opcode, operands, comment, cycles, cycles, bytes)
        if bLoad:
            self.reg.Invalidate(regLdSt)

    def gen_loadeffaddr_offset(self, regDst, offset, regSrc, comment):
        opcode = f"lea{regName[regDst]}"
        if offset == 0:
            operands = f",{regName[regSrc]}"
        else:
            operands = f"{int(offset)},{regName[regSrc]}"
        cycles6309 = 4
        cycles6809 = 4
        bytes = 2
        if offset == 0:
            pass
        elif offset < 16 and offset >= -16:
            cycles6309 += 1
            cycles6809 += 1
            bytes += 0
        elif offset < 128 and offset >= -128:
            cycles6309 += 1
            cycles6809 += 1
            bytes += 1
        else:
            cycles6309 += 3
            cycles6809 += 4
            bytes += 2
        self.emit_op(opcode, operands, comment, cycles6309, cycles6809, bytes)


# *************************************************************************************************
# Sprite class: object definition, parsing, pre/post processing
# *************************************************************************************************

class Sprite:
    def __init__(self, name):
        # member variables which are read from sprite file
        self.name = name
        self.width = 0
        self.height = 0
        self.hasSinglePixelPos = False
        self.hasRowPointerArray = False
        self.matrix = []
        self.hotspot = (0, 0)
        # member variables which are calculated
        self.numPixels = 0
        self.numSavedBytes = 0
        self.rowStripList = []
        self.originXsprite = 0  # Index of pixel column is sprite which contains the hotspot.
                                # Note that the difference between originXsprite and originXcode must be an even number
        self.originXcode = 0    # Index of pixel column in sprite which will be written into left pixel (MSB) of
                                # the byte to which the destination pointer is pointing when DrawLeft is called.
                                # When DrawRight is called, this pixel will be written into the right (LSB) of the destination byte
        self.funcErase = AsmStream(f"Erase_{name}")
        self.funcDraw = [ None, None ]

    def ReadInputLine(self, line):
        pivot = line.find('=')
        if pivot != -1:
            key = line[0:pivot].strip().lower()
            value = line[pivot+1:].strip()
            if key == "width":
                self.width = int(value)
            elif key == "height":
                self.height = int(value)
            elif key == "singlepixelposition":
                self.hasSinglePixelPos = (value.lower() == "true")
            elif key == "rowpointerarray":
                self.hasRowPointerArray = (value.lower() == "true")
            elif key == "hotspot":
                coords = [ int(v) for v in value[1:-1].split(',') ]
                self.hotspot = (coords[0], coords[1])
            else:
                print(f"illegal line in Sprite '{self.name}' definition: {line}")
        else:
            rowpix = line.split()
            if len(rowpix) == self.width:
                self.matrix.append([-1 if val == "-" else int(val,16) for val in rowpix])
            else:
                print(f"illegal line in Sprite '{self.name}' definition: {line}")

    def FinishDefinition(self):
        # check that we loaded all rows of the matrix
        if len(self.matrix) != self.height:
            print(f"Sprite [{self.name}] error: Matrix height {int(len(self.matrix))} doesn't match sprite height {int(self.height)}")
        # create one or two draw functions
        if self.hasSinglePixelPos:
            self.funcDraw[0] = AsmStream(f"DrawLeft_{self.name}")
            self.funcDraw[1] = AsmStream(f"DrawRight_{self.name}")
        else:
            self.funcDraw[0] = AsmStream(f"Draw_{self.name}")

    def Process1_PreCalc(self):
        # analyze each row and make list of non-transparent strips (consecutive pixels)
        for y in range(self.height):
            stripList = []
            stripStart = None
            for x in range(self.width):
                isTransparent = (self.matrix[y][x] == -1)
                if not isTransparent:
                    self.numPixels += 1
                if not isTransparent and stripStart == None:
                    # start new strip here
                    stripStart = x
                elif isTransparent and stripStart != None:
                    # strip ends here
                    stripLen = x - stripStart
                    stripList.append((stripStart, stripLen))
                    stripStart = None
            # handle strip which ends on last column of row
            if stripStart != None:
                stripLen = self.width - stripStart
                stripList.append((stripStart, stripLen))
            # append this strip array to the row list
            self.rowStripList.append(stripList)
        # calculate OriginX
        self.originXsprite = self.hotspot[0]
        self.originXcode = ((self.width >> 1) & ~1) | (self.originXsprite & 1)

    # *************************************************************************************************
    # Sprite class: Erase function generation
    # *************************************************************************************************

    def Process2_GenErase(self):
        # print input conditions
        self.funcErase.emit_comment("Input:   X = Pointer to buffer containing saved pixel data")
        self.funcErase.emit_comment("         Y = Pointer to graphics memory")
        if CPU == 6309:
            self.funcErase.emit_comment("Trashed: X,Y,D,W")
        else:
            self.funcErase.emit_comment("Trashed: X,Y,D")
        # this gives the offset (relative to X pointer) from which newly restored bytes will be loaded
        SrcPtrOffNew = 0
        # the lineAdvance parameter gives the offset in rows to the line in graphics memory which we are writing
        lineAdvance = 0
        # the DstCenterOff holds the difference between the center of the sprite and the current destination pointer (Y)
        # this is only non-zero when using TFM instructions for 6309 code generation
        DstCenterOff = 0
        # iterate over all of the lines
        for y in range(self.height):
            stripList = self.rowStripList[y]
            if len(stripList) == 0:
                # fixme handle hasRowPointerArray here and other places below
                lineAdvance += 1
                continue
            # generate a list of all the byte offsets which must be stored
            byteList = []
            for x in range(self.width):
                if self.matrix[y][x] == -1:
                    continue
                byteOffL = (x - self.originXcode) >> 1
                byteOffR = (x - self.originXcode + 1) >> 1
                if len(byteList) == 0 or byteList[-1] != byteOffL:
                    byteList.append(byteOffL)
                if self.hasSinglePixelPos and byteList[-1] != byteOffR:
                    byteList.append(byteOffR)
            # now, generate a list of byte strips which must be copied
            byteStripList = []
            byteStart = byteList[0]
            byteLen = 1
            for offX in byteList[1:]:
                if offX == byteStart + byteLen:
                    byteLen += 1
                    continue
                byteStripList.append((byteStart, byteLen))
                byteStart = offX
                byteLen = 1
            byteStripList.append((byteStart, byteLen))
            # figure out how many bytes to restore in total
            for strip in byteStripList:
                self.numSavedBytes += strip[1]
            # handle each byte strip separately, and for each strip, decide whether to copy the strip
            # using accumulator load/store instructions, or (6309-only) using TFM instruction
            for stripIdx in range(len(byteStripList)):
                strip = byteStripList[stripIdx]
                # first, try the erase operation with load/store accumulator instructions
                asmStripAccum = AsmStream(None, copy.deepcopy(self.funcErase.reg))
                SrcPtrOffAccum = SrcPtrOffNew
                lineAdvanceAccum = lineAdvance
                DstCenterOffAccum = DstCenterOff
                # accum: figure out how many individual load/store operations we might do before hitting a TFM or the next line
                numLoadCommands = 0
                nextTFMStart = None
                for idx in range(stripIdx,len(byteStripList)):
                    if CPU == 6309:
                        if strip[1] == 7 or strip[1] >= 9:
                            # this strip will probably be done with TFM, so we will need to adjust destination (leay)
                            # at this point
                            nextTFMStart = strip[0]
                            break
                        numLoadCommands += (strip[1] >> 2) + ((strip[1] & 2) >> 1) + (strip[1] & 1)
                    else:
                        numLoadCommands += (strip[1] >> 1) + (strip[1] & 1)
                # accum: if necessary, advance the source (X) pointer
                if SrcPtrOffAccum + strip[1] > 64:
                    bytesToAdvance = SrcPtrOffAccum + 16
                    asmStripAccum.gen_loadeffaddr_offset(regX, bytesToAdvance, regX, "")
                    SrcPtrOffAccum = -16
                # accum: if necessary, advance the destination (Y) pointer across lines
                if lineAdvanceAccum > 0 and numLoadCommands > 2:
                    if nextTFMStart == None:
                        nextDstCenterOff = 0
                    else:
                        nextDstCenterOff = nextTFMStart
                    bytesToAdvance = (256 * lineAdvanceAccum) - DstCenterOffAccum + nextDstCenterOff
                    asmStripAccum.gen_loadeffaddr_offset(regY, bytesToAdvance, regY, "")
                    lineAdvanceAccum = 0
                    DstCenterOffAccum = nextDstCenterOff
                # accum: emit code to store each bytes containing pixels in this strip
                if CPU == 6309:
                    # accum: copy strip in 32-bit dwords
                    while strip[1] >= 4:
                        asmStripAccum.gen_loadstore_indexed(True, regQ, regX, SrcPtrOffAccum, "")
                        SrcPtrOffAccum += 4
                        asmStripAccum.gen_loadstore_indexed(False, regQ, regY, strip[0] + 256*lineAdvanceAccum - DstCenterOffAccum, "")
                        strip = (strip[0] + 4, strip[1] - 4)
                # accum: copy strip in words
                while strip[1] >= 2:
                    asmStripAccum.gen_loadstore_indexed(True, regD, regX, SrcPtrOffAccum, "")
                    SrcPtrOffAccum += 2
                    asmStripAccum.gen_loadstore_indexed(False, regD, regY, strip[0] + 256*lineAdvanceAccum - DstCenterOffAccum, "")
                    strip = (strip[0] + 2, strip[1] - 2)
                #        if strip is odd length, copy a byte
                if strip[1] == 1:
                    asmStripAccum.gen_loadstore_indexed(True, regA, regX, SrcPtrOffAccum, "")
                    SrcPtrOffAccum += 1
                    asmStripAccum.gen_loadstore_indexed(False, regA, regY, strip[0] + 256*lineAdvanceAccum - DstCenterOffAccum, "")
                    strip = (strip[0] + 1, strip[1] - 1)
                # then try the erase operation with TFM instructions
                if CPU == 6309:
                    asmStripTfm = AsmStream(None, copy.deepcopy(self.funcErase.reg))
                    SrcPtrOffTfm = SrcPtrOffNew
                    lineAdvanceTfm = lineAdvance
                    DstCenterOffTfm = DstCenterOff
                    strip = byteStripList[stripIdx]
                    # tfm: if necessary, advance the source (X) pointer
                    if SrcPtrOffTfm != 0:
                        bytesToAdvance = SrcPtrOffTfm
                        asmStripTfm.gen_loadeffaddr_offset(regX, bytesToAdvance, regX, "")
                        SrcPtrOffTfm = 0
                    # tfm: if necessary, advance the destination (Y) pointer to start of copy output region
                    if lineAdvanceTfm > 0 or DstCenterOffTfm != strip[0]:
                        bytesToAdvance = (256 * lineAdvanceTfm) - DstCenterOffTfm + strip[0]
                        asmStripTfm.gen_loadeffaddr_offset(regY, bytesToAdvance, regY, "")
                        lineAdvanceTfm = 0
                        DstCenterOffTfm = strip[0]
                    # tfm: load number of bytes to copy in W register
                    asmStripTfm.gen_loadimm_accum(regW, strip[1], "")
                    # tfm: do the copy
                    cycles = 6 + 3 * strip[1]
                    asmStripTfm.emit_op("tfm", "x+,y+", "", cycles, cycles, 3)
                    asmStripTfm.reg.SetValue(regW, 0)
                    # tfm: source pointer was advanced, so still at 0, so no need to update SrcPtrOffTfm
                    # tfm: destination pointer was advanced, so update DstCenterOffTfm
                    DstCenterOffTfm += strip[1]
                # finally, decide whether the Accumulator or TFM methods was faster, and renconcile our state accordingly
                if CPU == 6309 and asmStripTfm.metrics.cycles < asmStripAccum.metrics.cycles:
                    self.funcErase += asmStripTfm
                    SrcPtrOffNew = SrcPtrOffTfm
                    lineAdvance = lineAdvanceTfm
                    DstCenterOff = DstCenterOffTfm
                else:
                    self.funcErase += asmStripAccum
                    SrcPtrOffNew = SrcPtrOffAccum
                    lineAdvance = lineAdvanceAccum
                    DstCenterOff = DstCenterOffAccum
                # now we loop back and do the remaining strips in this row
            # next iteration will be on the next line
            lineAdvance += 1
        # dump out return instruction
        self.funcErase.emit_op("rts", "", "", 5, 4, 1)

    # *************************************************************************************************
    # Sprite class: Draw function generation
    # *************************************************************************************************

    def Process3_GenDraw(self, funcNum):
        # funcNum 0 is for Draw/DrawLeft, funcNum 1 if for DrawRight
        funcDraw = self.funcDraw[funcNum]
        # print input conditions
        funcDraw.emit_comment("Input:   X = Pointer to graphics memory")
        funcDraw.emit_comment("         Y = Pointer to buffer for storing background pixel data")
        if CPU == 6309:
            funcDraw.emit_comment("Trashed: X,Y,D,W,U")
        else:
            funcDraw.emit_comment("Trashed: X,Y,D,U")
        # start by generating the Byte Command Strip List for all of the rows
        byteStripsByRow = [ ]
        for y in range(self.height):
            stripList = self.rowStripList[y]
            if len(stripList) == 0:
                byteStripsByRow.append([])
                continue
            # generate a list of all the byte offsets which must be stored (same as in Erase function)
            byteStoreList = []
            for x in range(self.width):
                if self.matrix[y][x] == -1:
                    continue
                byteOffL = (x - self.originXcode) >> 1
                byteOffR = (x - self.originXcode + 1) >> 1
                if len(byteStoreList) == 0 or byteStoreList[-1] != byteOffL:
                    byteStoreList.append(byteOffL)
                if self.hasSinglePixelPos and byteStoreList[-1] != byteOffR:
                    byteStoreList.append(byteOffR)
            # now generate a list of byte commands for the given draw routine
            # - Command 0: ignore (no Write routines modify either nibble in byte)
            # - Command 1: store only (other Write routine modifies byte)
            # - Command 2: store and write 1 nibble
            # - Command 3: store and write both nibbles
            byteCmds = [ ]  # value is (command number, value to store, mask)
            byteOffStart = (0 - self.originXcode) >> 1
            byteOffEnd = (self.width - self.originXcode) >> 1
            for offX in range(byteOffStart,byteOffEnd+1):
                pixNibL = ((offX << 1) + self.originXcode - funcNum)
                pixNibR = pixNibL + 1
                nibToWrite = 0
                valToWrite = 0
                maskToWrite = 0xff
                if pixNibL >= 0 and pixNibL < self.width and self.matrix[y][pixNibL] != -1:
                    nibToWrite += 1
                    valToWrite = (self.matrix[y][pixNibL] << 4)
                    maskToWrite = (maskToWrite & 0x0f)
                if pixNibR >= 0 and pixNibR < self.width and self.matrix[y][pixNibR] != -1:
                    nibToWrite += 1
                    valToWrite += self.matrix[y][pixNibR]
                    maskToWrite = (maskToWrite & 0xf0)
                # generate the command
                if offX not in byteStoreList:
                    if nibToWrite != 0:
                        raise Exception(f"Logical error: byte offset {int(offX)} not in store list, but nibToWrite is {int(nibToWrite)}")
                    byteCmds.append((0, 0, 0))
                    continue
                if nibToWrite == 0:
                    byteCmds.append((1, 0, 0))
                    continue
                if nibToWrite == 1:
                    byteCmds.append((2, valToWrite, maskToWrite))
                    continue
                byteCmds.append((3, valToWrite, 0))
            # convert the list of byte commands into a list of strips with consecutive non-command-0 bytes
            # byteStrips is list of tuples: (byteOffsetStart, [ (command number, value to store, mask), ... ] )
            numBytes = byteOffEnd - byteOffStart + 1
            byteStrips = [ ]
            byteCmdStart = None
            thisStrip = [ ]
            for idx in range(numBytes+1):
                byteOff = byteOffStart + idx
                if idx == numBytes or byteCmds[idx][0] == 0:
                    # command 0 - ignore this byte
                    if byteCmdStart != None:
                        byteStrips.append((byteCmdStart, thisStrip))
                        byteCmdStart = None
                        thisStrip = [ ]
                    continue
                # command 1, 2, or 3
                if byteCmdStart == None:
                    byteCmdStart = byteOff
                thisStrip.append(byteCmds[idx])
            byteStripsByRow.append(byteStrips)
            # process the next row
        # build some custom data structures for the algorithm corresponding with the target CPU
        if CPU == 6309:
            pass
        else:
            # now we will generate lists of bytes or words (pure command3) which may be written in a line
            # we will also calculate a 'probability' for each byte/word, so that we will prefer those bytes/words
            # which are more likely to be written.  this is to minimize cross-row loads
            self.byteWriteProbByRow = [ ]
            self.wordWriteProbByRow = [ ]
            for y in range(self.height):
                byteStrips = byteStripsByRow[y]
                if len(byteStrips) == 0:
                    self.byteWriteProbByRow.append({})
                    self.wordWriteProbByRow.append({})
                    continue
                byteWriteCntByVal = { }
                wordWriteCntByVal = { }
                totalBytes = 0
                totalWords = 0
                # iterate over all of the strips
                for (offX,byteCmds) in byteStrips:
                    bytesInStrip = len(byteCmds)
                    # start with bytes (they're easier)
                    if (bytesInStrip & 1) == 1:
                        for idx in range(0, bytesInStrip, 2):
                            # we only care about command-3 bytes
                            if byteCmds[idx][0] == 3:
                                writeVal = byteCmds[idx][1]
                                if writeVal in byteWriteCntByVal:
                                    byteWriteCntByVal[writeVal] += 1
                                else:
                                    byteWriteCntByVal[writeVal] = 1
                                totalBytes += 1
                    # next do words for even-length strips, or words on even byte boundary in odd-length strip
                    if bytesInStrip > 1:
                        for idx in range(0, bytesInStrip-1, 2):
                            # we only care about words containing both command-3 bytes
                            if byteCmds[idx][0] == 3 and byteCmds[idx+1][0] == 3:
                                writeVal = (byteCmds[idx][1] << 8) + byteCmds[idx+1][1]
                                if writeVal in wordWriteCntByVal:
                                    wordWriteCntByVal[writeVal] += 1
                                else:
                                    wordWriteCntByVal[writeVal] = 1
                                totalWords += 1
                    # finally, do words on odd-byte boundary in an odd-length strip
                    if bytesInStrip > 1 and (bytesInStrip & 1) == 1:
                        # do all words on an odd byte boundary
                        for idx in range(1, bytesInStrip-1, 2):
                            # we only care about words containing both command-3 bytes
                            if byteCmds[idx][0] == 3 and byteCmds[idx+1][0] == 3:
                                writeVal = (byteCmds[idx][1] << 8) + byteCmds[idx+1][1]
                                if writeVal in wordWriteCntByVal:
                                    wordWriteCntByVal[writeVal] += 1
                                else:
                                    wordWriteCntByVal[writeVal] = 1
                                totalWords += 1
                # now generate dictionaries containing writeValue ==> probability
                byteWriteProb = { }
                wordWriteProb = { }
                for val in byteWriteCntByVal:
                    byteWriteProb[val] = float(byteWriteCntByVal[val]) / totalBytes
                for val in wordWriteCntByVal:
                    wordWriteProb[val] = float(wordWriteCntByVal[val]) / totalWords
                # add these dictionaries to the row lists
                self.byteWriteProbByRow.append(byteWriteProb)
                self.wordWriteProbByRow.append(wordWriteProb)
        # main loop of Draw generator: process each line separately
        # YPtrOffNew gives the offset (relative to Y pointer) to which background graphic bytes will be saved
        self.YPtrOffNew = 0
        # the lineAdvance parameter gives the offset in rows to the line in graphics memory which we are writing
        self.lineAdvance = 0
        # but this is only used for the 6809. For the 6309, we always use "addr U,X" to advance one row
        if CPU == 6309:
            funcDraw.emit_op("ldu","#256","", 3, 3, 3);
        # now we will generate optimized assembly code for each row
        regState = AsmRegisters()
        for y in range(self.height):
            # get list of byte command strips for this row, and count total number of bytes to save
            byteStrips = byteStripsByRow[y]
            totalBytesToSave = 0
            if len(byteStrips) == 0:
                # fixme handle hasRowPointerArray here and other places below
                self.lineAdvance += 1
                continue
            for cmdStrip in byteStrips:
                totalBytesToSave += len(cmdStrip[1])
            # set a flag if we will only store one byte or one word for this row
            bSingleWriteOp = totalBytesToSave < 2 or (totalBytesToSave == 2 and len(byteStrips) == 1)
            # advance the Y pointer if necessary
            if self.YPtrOffNew + totalBytesToSave > 64:
                bytesToAdvance = self.YPtrOffNew + 16
                funcDraw.gen_loadeffaddr_offset(regY, bytesToAdvance, regY, "")
                self.YPtrOffNew = -16
            # advance the X pointer if necessary
            if CPU == 6309:
                if self.lineAdvance == 1:
                    funcDraw.emit_op("addr", "u,x", "", 4, 4, 3)
                elif self.lineAdvance > 1:
                    funcDraw.gen_loadeffaddr_offset(regX, 256*self.lineAdvance, regX, "")
                self.lineAdvance = 0
            else:
                if self.lineAdvance > 0 and not bSingleWriteOp:
                    funcDraw.gen_loadeffaddr_offset(regX, 256*self.lineAdvance, regX, "")
                    self.lineAdvance = 0
            # fixme save the YPtrOffNew here if hasRowPointerArray is true
            if self.hasRowPointerArray:
                funcDraw.emit_label(f"Row{int(y)}_{funcDraw.name}")
            # call the specific row handler method for the current CPU
            if CPU == 6309:
                rowAsm = self.RowDraw6309(y, regState, byteStrips)
            else:
                rowAsm = self.RowDraw6809(y, regState, byteStrips)
            # update our draw function with the best Asm code for this row, and update our register state tracking variable
            funcDraw += rowAsm
            regState = rowAsm.reg
            # next iteration will be on the next line
            self.YPtrOffNew += totalBytesToSave
            self.lineAdvance += 1
        # dump out return instruction
        funcDraw.emit_op("rts", "", "", 5, 4, 1)


    # *************************************************************************************************
    # Sprite class: Draw function row generation for 6309
    # *************************************************************************************************

    def RowDraw6309(self, y, regState, byteStrips):
        # generate a byte command list, which is a list of tuples: (srcOffset, dstOffset, command, value, mask)
        byteOffCmdList = []
        dstOffset = 0
        for strip in byteStrips:
            off0 = strip[0]
            byteCmds = strip[1]
            for byteIdx in range(len(byteCmds)):
                thisCmd = byteCmds[byteIdx]
                byteOffCmdList.append((off0+byteIdx, dstOffset, thisCmd[0], thisCmd[1], thisCmd[2]))
                dstOffset += 1

        # in block of n commands, exhaustively search all permutations of store/write commands, and return best result
        # we choose n = 12 as a compromise for compile time performance and runtime performance
        n = 12
        layoutDict = { 1:[], 2:[], 4:[] }
        results = [self.Permute6309StoreLayouts(regState, layoutDict, byteOffCmdList[ii:ii + n], 4)
                      for ii in range(0, len(byteOffCmdList), n)]
        return_value = results[0]
        for ii in range(1, len(results)):
            return_value += results[ii]
        return return_value

    def Permute6309StoreLayouts(self, regState, layoutDict, byteOffCmdList, searchSize):
        cmdListLen = len(byteOffCmdList)
        if cmdListLen == 0:
            # this is a leaf node, so we need to emit the code for handling the Store operations
            startAsm = AsmStream(None, regState)
            writeByteList = [ ]
            layoutCopy = { 1:copy.copy(layoutDict[1]), 2:copy.copy(layoutDict[2]), 4:copy.copy(layoutDict[4]) }
            return self.Permute6309StoreCodeGen(startAsm, layoutCopy, writeByteList, 4, None)
        if searchSize == 4:
            # search for DWORDs that we can store
            bFoundCandidates = False
            for cmdIdx in range(cmdListLen-3):
                # are these bytes consecutive?
                if byteOffCmdList[cmdIdx+1][0] != byteOffCmdList[cmdIdx][0] + 1:
                    continue
                if byteOffCmdList[cmdIdx+2][0] != byteOffCmdList[cmdIdx][0] + 2:
                    continue
                if byteOffCmdList[cmdIdx+3][0] != byteOffCmdList[cmdIdx][0] + 3:
                    continue
                # can't use Q if the last 2 bytes require AND/OR (command 2)
                if byteOffCmdList[cmdIdx+2][2] == 2 or byteOffCmdList[cmdIdx+3][2] == 2:
                    continue
                # otherwise, this position is a candidate for Store operation with 32-bit Q accumulator
                DWordCmdList = []
                for i in range(4):
                    DWordCmdList.append((byteOffCmdList[cmdIdx+i][2], byteOffCmdList[cmdIdx+i][3], byteOffCmdList[cmdIdx+i][4]))
                layoutDict[4].append((byteOffCmdList[cmdIdx][0], byteOffCmdList[cmdIdx][1], DWordCmdList))
                newByteOffCmdList = byteOffCmdList[:cmdIdx] + byteOffCmdList[cmdIdx+4:]
                # recurse down into this case
                trialAsm = self.Permute6309StoreLayouts(regState, layoutDict, newByteOffCmdList, 4)
                # revert our layoutDict changes
                del layoutDict[4][-1]
                # update our bestAsm
                if not bFoundCandidates:
                    bFoundCandidates = True
                    bestAsm = trialAsm
                else:
                    bestAsm = self.BestResult(bestAsm, trialAsm)
                continue
            # if we found any DWORD candidates during this function search, then just return the best result
            if bFoundCandidates:
                return bestAsm
            # otherwise our search continues with WORDs
            searchSize = 2
        if searchSize == 2:
            # search for WORDs that we can store
            bFoundCandidates = False
            for cmdIdx in range(cmdListLen-1):
                # are these bytes consecutive?
                if byteOffCmdList[cmdIdx+1][0] != byteOffCmdList[cmdIdx][0] + 1:
                    continue
                # otherwise, this position is a candidate for Store operation with 16-bit D accumulator
                WordCmdList = []
                for i in range(2):
                    WordCmdList.append((byteOffCmdList[cmdIdx+i][2], byteOffCmdList[cmdIdx+i][3], byteOffCmdList[cmdIdx+i][4]))
                layoutDict[2].append((byteOffCmdList[cmdIdx][0], byteOffCmdList[cmdIdx][1], WordCmdList))
                newByteOffCmdList = byteOffCmdList[:cmdIdx] + byteOffCmdList[cmdIdx+2:]
                # recurse down into this case
                trialAsm = self.Permute6309StoreLayouts(regState, layoutDict, newByteOffCmdList, 2)
                # revert our layoutDict changes
                del layoutDict[2][-1]
                # update our bestAsm
                if not bFoundCandidates:
                    bFoundCandidates = True
                    bestAsm = trialAsm
                else:
                    bestAsm = self.BestResult(bestAsm, trialAsm)
                continue
            # if we found any WORD candidates during this function search, then just return the best result
            if bFoundCandidates:
                return bestAsm
            # otherwise our search continues with BYTEs
            searchSize = 1
        # search size must be 1
        if searchSize != 1:
            raise Exception("Error: searchSize != 1 at end of Permute6309StoreLayouts!")
        # recurse over all possible orderings of BYTEs to store
        bFoundCandidates = False
        for cmdIdx in range(cmdListLen):
            layoutDict[1].append(byteOffCmdList[cmdIdx])
            newByteOffCmdList = byteOffCmdList[:cmdIdx] + byteOffCmdList[cmdIdx+1:]
            # recurse down into this case
            trialAsm = self.Permute6309StoreLayouts(regState, layoutDict, newByteOffCmdList, 1)
            # revert our layoutDict changes
            del layoutDict[1][-1]
            # update our bestAsm
            if not bFoundCandidates:
                bFoundCandidates = True
                bestAsm = trialAsm
            else:
                bestAsm = self.BestResult(bestAsm, trialAsm)
            continue
        # return the best result
        return bestAsm

    def Permute6309StoreCodeGen(self, bestRowAsm, layoutDict, writeByteList, storeSize, scratchReg):
        if storeSize == 1 and len(layoutDict[1]) == 0:
            # this is a leaf node, so we need to permute across all possible variations of Write operations
            # start by make a copy of our list of bytes to write, and then sorting it
            writeByteListCopy = copy.copy(writeByteList)
            writeByteListCopy.sort()
            # it will be sorted primarily by the first element in the tuple, which is offX
            # now call a function to permute all possible write commands
            layoutDict = { 1:[], 2:[], 4:[] }
            return self.Permute6309WriteLayouts(bestRowAsm, layoutDict, writeByteListCopy, 4)
        if storeSize == 4:
            # if there are no 4-byte stores left, then recurse to handle 2-byte stores
            if len(layoutDict[4]) == 0:
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 2, None)
            # store the first DWORD in the list
            store4Cmds = layoutDict[4].pop(0)
            offX = store4Cmds[0]
            offY = self.YPtrOffNew + store4Cmds[1]
            bestRowAsm.gen_loadstore_indexed(True, regQ, regX, offX, "")  # ldq off,x
            bestRowAsm.gen_loadstore_indexed(False, regQ, regY, offY, "")
            # if this 4-byte store contains command-2 bytes in the lower 2 positions, then crash
            if store4Cmds[2][2][0] == 2 or store4Cmds[2][3][0] == 2:
                raise Exception("Error: word in 32-bit store command contains Command-2 bytes in low WORD!")
            # if this 4-byte store contains no command-2 bytes, just add to the WriteByteList and continue with next DWORD
            if store4Cmds[2][0][0] != 2 and store4Cmds[2][1][0] != 2:
                for byteIdx in range(4):
                    cmd = store4Cmds[2][byteIdx]
                    if cmd[0] == 3:
                        writeByteList.append((offX+byteIdx, cmd[1]))
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 4, None)
            # generate AND/OR instructions to handle command-2 bytes in A and/or B registers
            self.GenerateCommand2RegisterOps(store4Cmds[2][0], store4Cmds[2][1], bestRowAsm)
            # if all 4 bytes are going to be written, then we should write them now (faster)
            if store4Cmds[2][0][0] > 1 and store4Cmds[2][1][0] > 1 and store4Cmds[2][2][0] == 3 and store4Cmds[2][3][0] == 3:
                if store4Cmds[2][0][0] == 3:
                    bestRowAsm.gen_loadimm_accum(regA, store4Cmds[2][0][1], "")
                elif store4Cmds[2][1][0] == 3:
                    bestRowAsm.gen_loadimm_accum(regB, store4Cmds[2][1][1], "")
                wordLoad = (store4Cmds[2][2][1] << 8) + store4Cmds[2][3][1]
                bestRowAsm.gen_loadimm_accum(regW, wordLoad, "")
                bestRowAsm.gen_loadstore_indexed(False, regQ, regX, offX, "") # stq off,x
                # fixme optimize: permute all possible byte/word stores with valid accumulators now
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 4, None)
            # put lower 2 bytes into write list, we will deal with them later
            for byteIdx in range(2,4):
                cmd = store4Cmds[2][byteIdx]
                if cmd[0] == 3:
                    writeByteList.append((offX+byteIdx, cmd[1]))
            # if only one of the 2 upper bytes needs to be written, the write it and continue
            if store4Cmds[2][0][0] == 1: # only write B
                bestRowAsm.gen_loadstore_indexed(False, regB, regX, offX+1, "")  # stb off,x
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 4, None)
            if store4Cmds[2][1][0] == 1: # only write A
                bestRowAsm.gen_loadstore_indexed(False, regA, regX, offX, "")  # sta off,x
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 4, None)
            # if both upper bytes are command-2, write D and continue
            if store4Cmds[2][0][0] == 2 and store4Cmds[2][1][0] == 2:
                bestRowAsm.gen_loadstore_indexed(False, regD, regX, offX, "")  # std off,x
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 4, None)
            # now we're in a situation where one byte is ready to write (command-2), but the other is command-3
            # we will write them both now with reg D
            if store4Cmds[2][0][0] == 3:
                bestRowAsm.gen_loadimm_accum(regA, store4Cmds[2][0][1], "")
            else:
                bestRowAsm.gen_loadimm_accum(regB, store4Cmds[2][1][1], "")
            bestRowAsm.gen_loadstore_indexed(False, regD, regX, offX, "")  # std off,x
            return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 4, None)
        if storeSize == 2:
            # if there are no 2-byte stores left, then recurse to handle 1-byte stores
            if len(layoutDict[2]) == 0:
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 1, None)
            # store the first WORD in the list
            store2Cmds = layoutDict[2].pop(0)
            offX = store2Cmds[0]
            offY = self.YPtrOffNew + store2Cmds[1]
            bestRowAsm.gen_loadstore_indexed(True, regD, regX, offX, "")  # ldd off,x
            bestRowAsm.gen_loadstore_indexed(False, regD, regY, offY, "")
            # if this 2-byte store contains no command-2 bytes, just add to the WriteByteList and continue with next DWORD
            if store2Cmds[2][0][0] != 2 and store2Cmds[2][1][0] != 2:
                for byteIdx in range(2):
                    cmd = store2Cmds[2][byteIdx]
                    if cmd[0] == 3:
                        writeByteList.append((offX+byteIdx, cmd[1]))
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 2, None)
            # generate AND/OR instructions to handle command-2 bytes in A and/or B registers
            self.GenerateCommand2RegisterOps(store2Cmds[2][0], store2Cmds[2][1], bestRowAsm)
            # if only one of the 2 upper bytes needs to be written, the write it and continue
            if store2Cmds[2][0][0] == 1: # only write B
                bestRowAsm.gen_loadstore_indexed(False, regB, regX, offX+1, "")  # stb off,x
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 2, None)
            if store2Cmds[2][1][0] == 1: # only write A
                bestRowAsm.gen_loadstore_indexed(False, regA, regX, offX, "")  # sta off,x
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 2, None)
            # if both upper bytes are command-2, write D and continue
            if store2Cmds[2][0][0] == 2 and store2Cmds[2][1][0] == 2:
                bestRowAsm.gen_loadstore_indexed(False, regD, regX, offX, "")  # std off,x
                return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 2, None)
            # now we're in a situation where one byte is ready to write (command-2), but the other is command-3
            # we will write them both now with reg D
            if store2Cmds[2][0][0] == 3:
                bestRowAsm.gen_loadimm_accum(regA, store2Cmds[2][0][1], "")
            else:
                bestRowAsm.gen_loadimm_accum(regB, store2Cmds[2][1][1], "")
            bestRowAsm.gen_loadstore_indexed(False, regD, regX, offX, "")  # std off,x
            # fixme optimize: permute all possible byte/word stores with valid accumulators now
            return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 2, None)
        # store size must be 1
        if storeSize != 1:
            raise Exception("Error: storeSize != 1 at end of Permute6309StoreCodeGen!")
        # figure out whiche register to use as scratch for the byte stores
        if scratchReg == None:
            if not bestRowAsm.reg.IsValid(regA):
                scratchReg = regA
            elif not bestRowAsm.reg.IsValid(regB):
                scratchReg = regB
            else:
                # both A and B are valid, so permute over 2 possible cases and return best
                trial1Asm = copy.deepcopy(bestRowAsm)
                layoutCopy = { 1:copy.copy(layoutDict[1]), 2:copy.copy(layoutDict[2]), 4:copy.copy(layoutDict[4]) }
                trial1Asm = self.Permute6309StoreCodeGen(trial1Asm, layoutCopy, copy.copy(writeByteList), 1, regA)
                # then try out the second case
                trial2Asm = bestRowAsm
                trial2Asm = self.Permute6309StoreCodeGen(trial2Asm, layoutDict, writeByteList, 1, regB)
                # now choose the best option
                return self.BestResult(trial1Asm, trial2Asm)
        # store each BYTE in the list
        while len(layoutDict[1]) > 0:
            store1Cmd = layoutDict[1].pop(0)
            offX = store1Cmd[0]
            offY = self.YPtrOffNew + store1Cmd[1]
            bestRowAsm.gen_loadstore_indexed(True, scratchReg, regX, offX, "")
            bestRowAsm.gen_loadstore_indexed(False, scratchReg, regY, offY, "")
            # if this is Command-1 then we're done
            if store1Cmd[2] == 1:
                continue
            # if this is Command-2 then update and write
            if store1Cmd[2] == 2:
                # we don't need to clear bits with AND mask if nybble we're writing is 15
                if (store1Cmd[3] | store1Cmd[4]) != 0xff:
                    bestRowAsm.emit_op(f"and{regName[scratchReg]}", (f"#${store1Cmd[4]:02x}"), "", 2, 2, 2)
                # we don't need to write nybble with OR if we're writing 0
                if store1Cmd[3] != 0:
                    bestRowAsm.emit_op(f"or{regName[scratchReg]}", (f"#${store1Cmd[3]:02x}"), "", 2, 2, 2)
                bestRowAsm.gen_loadstore_indexed(False, scratchReg, regX, offX, "")
                continue
            # if this is Command-3, add it to the byte write list and continue
            if store1Cmd[2] != 3:
                raise Exception("Error: command number for byte store != 3 at end of Permute6309StoreCodeGen!")
            writeByteList.append((offX, store1Cmd[3]))
        # now the store operations are all completed, so we will recurse into ourself to start the writes
        return self.Permute6309StoreCodeGen(bestRowAsm, layoutDict, writeByteList, 1, scratchReg)

    def BestResult(self, trial1Asm, trial2Asm):
        if trial1Asm.metrics.cycles < trial2Asm.metrics.cycles or (trial1Asm.metrics.cycles == trial2Asm.metrics.cycles and trial1Asm.metrics.bytes <= trial2Asm.metrics.bytes):
            return trial1Asm
        else:
            return trial2Asm

    def GenerateCommand2RegisterOps(self, byteCmd1, byteCmd2, rowAsm):
        if byteCmd1[0] == 2 and byteCmd2[0] == 2:
            byteSplit = False
            # we don't need to clear bits with AND mask if nybble we're writing is 15
            if (byteCmd1[1] | byteCmd1[2]) != 0xff:
                rowAsm.emit_op("anda", (f"#${byteCmd1[2]:02x}"), "", 2, 2, 2)
            else:
                byteSplit = True
            if (byteCmd2[1] | byteCmd2[2]) != 0xff:
                rowAsm.emit_op("andb", (f"#${byteCmd2[2]:02x}"), "", 2, 2, 2)
            else:
                byteSplit = True
            if byteSplit:
                # we don't need to write nybble with OR if we're writing 0
                if byteCmd1[1] != 0:
                    rowAsm.emit_op("ora", (f"#${byteCmd1[1]:02x}"), "", 2, 2, 2)
                if byteCmd2[1] != 0:
                    rowAsm.emit_op("orb", (f"#${byteCmd2[1]:02x}"), "", 2, 2, 2)
            else:
                wordAdd = (byteCmd1[1] << 8) + byteCmd2[1]
                if wordAdd != 0:
                    rowAsm.emit_op("addd", f"#${wordAdd:04x}", "", 4, 3, 3)
        elif byteCmd1[0] == 2:
            # we don't need to clear bits with AND mask if nybble we're writing is 15
            if (byteCmd1[1] | byteCmd1[2]) != 0xff:
                rowAsm.emit_op("anda", (f"#${byteCmd1[2]:02x}"), "", 2, 2, 2)
            # we don't need to write nybble with OR if we're writing 0
            if byteCmd1[1] != 0:
                rowAsm.emit_op("ora", (f"#${byteCmd1[1]:02x}"), "", 2, 2, 2)
        elif byteCmd2[0] == 2:
            # we don't need to clear bits with AND mask if nybble we're writing is 15
            if (byteCmd2[1] | byteCmd2[2]) != 0xff:
                rowAsm.emit_op("andb", (f"#${byteCmd2[2]:02x}"), "", 2, 2, 2)
            # we don't need to write nybble with OR if we're writing 0
            if byteCmd2[1] != 0:
                rowAsm.emit_op("orb", (f"#${byteCmd2[1]:02x}"), "", 2, 2, 2)

    def Permute6309WriteLayouts(self, startAsm, layoutDict, writeByteList, writeSize):
        writeListLen = len(writeByteList)
        if writeListLen == 0:
            layoutDict = { 1:copy.copy(layoutDict[1]), 2:copy.copy(layoutDict[2]), 4:copy.copy(layoutDict[4]) }
            # this is a leaf node, so we need to emit code to perform Write operations according to the order in our layout
            for write4Bytes in layoutDict[4]:
                startAsm.gen_loadimm_accum(regQ, write4Bytes[1], "")
                startAsm.gen_loadstore_indexed(False, regQ, regX, write4Bytes[0], "") # stq off,x
                # handle WORD write operations with D, W registers and BYTE write operations with A,B registers
                for write2Bytes in layoutDict[2][:]:
                    if write2Bytes[1] == startAsm.reg.GetValue(regD):
                        layoutDict[2].remove(write2Bytes)
                        startAsm.gen_loadstore_indexed(False, regD, regX, write2Bytes[0], "") # std off,x
                    elif write2Bytes[1] == startAsm.reg.GetValue(regW):
                        layoutDict[2].remove(write2Bytes)
                        startAsm.gen_loadstore_indexed(False, regW, regX, write2Bytes[0], "") # stw off,x
                for write1Bytes in layoutDict[1][:]:
                    if write1Bytes[1] == startAsm.reg.GetValue(regA):
                        layoutDict[1].remove(write1Bytes)
                        startAsm.gen_loadstore_indexed(False, regA, regX, write1Bytes[0], "") # sta off,x
                    elif write1Bytes[1] == startAsm.reg.GetValue(regB):
                        layoutDict[1].remove(write1Bytes)
                        startAsm.gen_loadstore_indexed(False, regB, regX, write1Bytes[0], "") # stb off,x
            for write2Bytes in layoutDict[2]:
                startAsm.gen_loadimm_accum(regD, write2Bytes[1], "")
                startAsm.gen_loadstore_indexed(False, regD, regX, write2Bytes[0], "") # std off,x
                # handle BYTE write operations with A/B registers
                for write1Bytes in layoutDict[1][:]:
                    if write1Bytes[1] == startAsm.reg.GetValue(regA):
                        layoutDict[1].remove(write1Bytes)
                        startAsm.gen_loadstore_indexed(False, regA, regX, write1Bytes[0], "") # sta off,x
                    elif write1Bytes[1] == startAsm.reg.GetValue(regB):
                        layoutDict[1].remove(write1Bytes)
                        startAsm.gen_loadstore_indexed(False, regB, regX, write1Bytes[0], "") # stb off,x
            for write1Bytes in layoutDict[1]:
                startAsm.gen_loadimm_accum(regA, write1Bytes[1], "")
                startAsm.gen_loadstore_indexed(False, regA, regX, write1Bytes[0], "") # sta off,x
            return startAsm
        if writeSize == 4:
            # search for DWORDs that we can write
            bFoundCandidates = False
            for writeIdx in range(writeListLen-3):
                # are these bytes consecutive?
                if writeByteList[writeIdx+1][0] != writeByteList[writeIdx][0] + 1:
                    continue
                if writeByteList[writeIdx+2][0] != writeByteList[writeIdx][0] + 2:
                    continue
                if writeByteList[writeIdx+3][0] != writeByteList[writeIdx][0] + 3:
                    continue
                # this position is a candidate for Write operation with 32-bit Q accumulator
                DWordValue = (writeByteList[writeIdx][1] << 24) + (writeByteList[writeIdx+1][1] << 16) + (writeByteList[writeIdx+2][1] << 8) + writeByteList[writeIdx+3][1]
                layoutDict[4].append((writeByteList[writeIdx][0], DWordValue))
                newWriteByteList = writeByteList[:writeIdx] + writeByteList[writeIdx+4:]
                # recurse down into this case
                trialAsm = self.Permute6309WriteLayouts(copy.deepcopy(startAsm), layoutDict, newWriteByteList, 4)
                # revert our layoutDict changes
                del layoutDict[4][-1]
                # update our bestAsm case
                if not bFoundCandidates:
                    bestAsm = trialAsm  # since this is our first candidate, it is currently the best
                    bFoundCandidates = True
                else:
                    bestAsm = self.BestResult(bestAsm, trialAsm)
                continue
            # if we found any DWORD candidates during this function search, then just return the best result
            if bFoundCandidates:
                return bestAsm
            # otherwise our search continues with WORDs
            writeSize = 2
        if writeSize == 2:
            # search for WORDs that we can write
            bFoundCandidates = False
            for writeIdx in range(writeListLen-1):
                # are these bytes consecutive?
                if writeByteList[writeIdx+1][0] != writeByteList[writeIdx][0] + 1:
                    continue
                # this position is a candidate for Write operation with 16-bit D accumulator
                WordValue = (writeByteList[writeIdx][1] << 8) + writeByteList[writeIdx+1][1]
                layoutDict[2].append((writeByteList[writeIdx][0], WordValue))
                newWriteByteList = writeByteList[:writeIdx] + writeByteList[writeIdx+2:]
                # recurse down into this case
                trialAsm = self.Permute6309WriteLayouts(copy.deepcopy(startAsm), layoutDict, newWriteByteList, 2)
                # revert our layoutDict changes
                del layoutDict[2][-1]
                # update our bestAsm case
                if not bFoundCandidates:
                    bestAsm = trialAsm  # since this is our first candidate, it is currently the best
                    bFoundCandidates = True
                else:
                    bestAsm = self.BestResult(bestAsm, trialAsm)
                continue
            # if we found any WORD candidates during this function search, then just return the best result
            if bFoundCandidates:
                return bestAsm
            # otherwise our search continues with BYTEs
            writeSize = 1
        # write size must be 1
        if writeSize != 1:
            raise Exception("Error: writeSize != 1 at end of Permute6309WriteLayouts!")
        # if there are no bytes to write, recurse into ourselves to emit the Write operation code
        if len(writeByteList) == 0:
            return self.Permute6309WriteLayouts(startAsm, layoutDict, writeByteList, 1)
        # try out all possible permutations of byte writes
        bFoundCandidates = False
        for writeIdx in range(writeListLen):
            writeByteCmd = writeByteList[writeIdx]
            layoutDict[1].append(writeByteCmd)
            newWriteByteList = writeByteList[:writeIdx] + writeByteList[writeIdx+1:]
            # recurse down into this case
            trialAsm = self.Permute6309WriteLayouts(copy.deepcopy(startAsm), layoutDict, newWriteByteList, 1)
            # revert our layoutDict changes
            del layoutDict[1][-1]
            # update our bestAsm case
            if not bFoundCandidates:
                bestAsm = trialAsm  # since this is our first candidate, it is currently the best
                bFoundCandidates = True
            else:
                bestAsm = self.BestResult(bestAsm, trialAsm)
            continue
        # we are completely done; return the best result
        return bestAsm

    # *************************************************************************************************
    # Sprite class: Draw function row generation for 6809
    # *************************************************************************************************

    def RowDraw6809(self, y, regState, byteStrips):
        # iterate through all permutations of byte/word layouts for strips to find fastest one
        layoutList = [ ]
        return self.PermuteByteStripLayouts(y, regState, layoutList, byteStrips)

    def PermuteByteStripLayouts(self, rowNum, regState, layoutList, remainingCmdStrips):
        # if we are at a leaf, then we have a complete row layout to turn into assembly code
        if len(remainingCmdStrips) == 0:
            rowAsm = self.GenRowCode(rowNum, copy.deepcopy(regState), layoutList)
            return rowAsm
        # otherwise we have more pixel strips to permute, so we will recurse
        activeByteCmdStrip = remainingCmdStrips[0]
        nextByteCmdStrips = remainingCmdStrips[1:]
        # if there is only one layout choice, then recurse into trivial case
        bytesInStrip = len(activeByteCmdStrip[1])
        if bytesInStrip == 1 or (bytesInStrip & 1) == 0:
            layoutList.append((activeByteCmdStrip, None))
            bestAsm = self.PermuteByteStripLayouts(rowNum, regState, layoutList, nextByteCmdStrips)
            layoutList.pop()
            return bestAsm
        # otherwise, iterate through each possible position for single byte in odd-length strip
        bestAsm = None
        for idx in range(0, bytesInStrip, 2):
            singleByteOffX = activeByteCmdStrip[0] + idx
            layoutList.append((activeByteCmdStrip, singleByteOffX))
            trialAsm = self.PermuteByteStripLayouts(rowNum, regState, layoutList, nextByteCmdStrips)
            layoutList.pop()
            if bestAsm == None or trialAsm.metrics.cycles < bestAsm.metrics.cycles:
                #if bestAsm != None:   # fixme debug
                #    print("%s: row layout with (cyc=%i,bytes=%i) is better than (cyc=%i,bytes=%i)" % (self.name, trialAsm.metrics.cycles, trialAsm.metrics.bytes, bestAsm.metrics.cycles, bestAsm.metrics.bytes))
                bestAsm = trialAsm
        # return the best one
        return bestAsm

    def GenRowCode(self, rowNum, regState, layoutList):
        rowAsm = AsmStream(None, regState)
        # generate cmdBytesToStore and cmdWordsToStore lists
        cmdBytesToStore = []
        cmdWordsToStore = []
        cmdBytesToWrite = []
        cmdWordsToWrite = []
        offY = self.YPtrOffNew
        for ((stripOffX,stripByteCmds), singleByteOffX) in layoutList:
            numByteCmds = len(stripByteCmds)
            offX = stripOffX
            while offX < stripOffX+numByteCmds:
                numLeft = stripOffX+numByteCmds - offX
                # do we process a single byte?
                if numLeft == 1 or singleByteOffX == offX:
                    byteCmd = stripByteCmds[offX-stripOffX]
                    cmdBytesToStore.append((offX, offY, byteCmd))
                    offX += 1
                    offY += 1
                    continue
                # otherwise we must process a word
                byteCmd1 = stripByteCmds[offX-stripOffX]
                byteCmd2 = stripByteCmds[offX-stripOffX+1]
                cmdWordsToStore.append((offX, offY, byteCmd1, byteCmd2))
                offX += 2
                offY += 2
        # use U to store all words with no command2 bytes
        idx = 0
        while idx < len(cmdWordsToStore):
            (offX,offY,byteCmd1,byteCmd2) = cmdWordsToStore[idx]
            if byteCmd1[0] != 2 and byteCmd2[0] != 2:
                # emit code to store the background word with U
                rowAsm.gen_loadstore_indexed(True, regU, regX, offX + 256*self.lineAdvance, "")  # ldu off,x
                rowAsm.gen_loadstore_indexed(False, regU, regY, offY, "")
                # move this command word into the cmdWordsToWrite or cmdBytesToWrite list
                if byteCmd1[0] == 1:
                    cmdWordsToStore.pop(idx)
                    cmdBytesToWrite.append((offX+1,offY+1,byteCmd2))
                elif byteCmd2[0] == 1:
                    cmdWordsToStore.pop(idx)
                    cmdBytesToWrite.append((offX,offY,byteCmd1))
                else:
                    cmdWordsToWrite.append(cmdWordsToStore.pop(idx))
                continue
            # we can't save this word right now, so skip it
            idx += 1
        # write all of the pure Command3 words which match D (if it's valid)
        if rowAsm.reg.IsValid(regD):
            idx = 0
            while idx < len(cmdWordsToWrite):
                (offX,offY,byteCmd1,byteCmd2) = cmdWordsToWrite[idx]
                if byteCmd1[1] == rowAsm.reg.GetValue(regA) and byteCmd2[1] == rowAsm.reg.GetValue(regB):
                    rowAsm.gen_loadstore_indexed(False, regD, regX, offX + 256*self.lineAdvance, "")  # std off,x
                    cmdWordsToWrite.pop(idx)
                    continue
                idx += 1
        # decide which byte register (A or B) to use as scratch.
        # preserve either register (A or B) which matches a Command-3 byte
        if not rowAsm.reg.IsValid(regA):
            scratchReg = regA
        elif not rowAsm.reg.IsValid(regB):
            scratchReg = regB
        else:
            scratchReg = regB
            for (offX,offY,(byteCmdNum,byteCmdVal,byteCmdMask)) in cmdBytesToStore + cmdBytesToWrite:
                if byteCmdNum != 3:
                    continue
                if byteCmdVal == rowAsm.reg.GetValue(regB):
                    scratchReg = regA
        # use the scratch register to store all bytes, and write all Command2 bytes
        while len(cmdBytesToStore) > 0:
            (offX,offY,byteCmd) = cmdBytesToStore.pop(0)
            rowAsm.gen_loadstore_indexed(True, scratchReg, regX, offX + 256*self.lineAdvance, "")
            rowAsm.gen_loadstore_indexed(False, scratchReg, regY, offY, "")
            if byteCmd[0] == 2:
                # we don't need to clear bits with AND mask if nybble we're writing is 15
                if (byteCmd[1] | byteCmd[2]) != 0xff:
                    rowAsm.emit_op(f"and{regName[scratchReg]}", (f"#${byteCmd[2]:02x}"), "", 2, 2, 2)
                if byteCmd[1] != 0:
                    rowAsm.emit_op(f"or{regName[scratchReg]}", (f"#${byteCmd[1]:02x}"), "", 2, 2, 2)
                rowAsm.gen_loadstore_indexed(False, scratchReg, regX, offX + 256*self.lineAdvance, "")
            elif byteCmd[0] == 3:
                cmdBytesToWrite.append((offX,offY,byteCmd))
        # write all Command3 bytes which match a valid register
        idx = 0
        while idx < len(cmdBytesToWrite):
            (offX,offY,byteCmd) = cmdBytesToWrite[idx]
            if byteCmd[0] != 3:
                raise Exception(f"Error: byte command {int(byteCmd[0])} is in the cmdBytesToWrite list!")
            if rowAsm.reg.IsValid(regA) and byteCmd[1] == rowAsm.reg.GetValue(regA):
                rowAsm.gen_loadstore_indexed(False, regA, regX, offX + 256*self.lineAdvance, "")  # sta off,x
                cmdBytesToWrite.pop(idx)
                continue
            elif rowAsm.reg.IsValid(regB) and byteCmd[1] == rowAsm.reg.GetValue(regB):
                rowAsm.gen_loadstore_indexed(False, regB, regX, offX + 256*self.lineAdvance, "")  # stb off,x
                cmdBytesToWrite.pop(idx)
                continue
            idx += 1
        # fixme (micro-op): if there is a word in cmdWordsToStore which contains a command-3 byte which
        # is part of the future lonelyBytes list, then put that word at end of list
        # use D (trashing it) to Store and Write the remaining unstored words (which all must have a Command2 byte)
        while len(cmdWordsToStore) > 0:
            (offX,offY,byteCmd1,byteCmd2) = cmdWordsToStore.pop(0)
            rowAsm.gen_loadstore_indexed(True, regD, regX, offX + 256*self.lineAdvance, "")  # ldd off,x
            rowAsm.gen_loadstore_indexed(False, regD, regY, offY, "")
            if byteCmd1[0] == 2 and byteCmd2[0] == 2:
                byteSplit = False
                # we don't need to clear bits with AND mask if nybble we're writing is 15
                if (byteCmd1[1] | byteCmd1[2]) != 0xff:
                    rowAsm.emit_op("anda", (f"#${byteCmd1[2]:02x}"), "", 2, 2, 2)
                else:
                    byteSplit = True
                if (byteCmd2[1] | byteCmd2[2]) != 0xff:
                    rowAsm.emit_op("andb", (f"#${byteCmd2[2]:02x}"), "", 2, 2, 2)
                else:
                    byteSplit = True
                if byteSplit:
                    # we don't need to write nybble with OR if we're writing 0
                    if byteCmd1[1] != 0:
                        rowAsm.emit_op("ora", (f"#${byteCmd1[1]:02x}"), "", 2, 2, 2)
                    if byteCmd2[1] != 0:
                        rowAsm.emit_op("orb", (f"#${byteCmd2[1]:02x}"), "", 2, 2, 2)
                else:
                    wordAdd = (byteCmd1[1] << 8) + byteCmd2[1]
                    if wordAdd != 0:
                        rowAsm.emit_op("addd", f"#${wordAdd:04x}", "", 4, 3, 3)
                rowAsm.gen_loadstore_indexed(False, regD, regX, offX + 256*self.lineAdvance, "")  # std off,x
            elif byteCmd1[0] == 2:
                # we don't need to clear bits with AND mask if nybble we're writing is 15
                if (byteCmd1[1] | byteCmd1[2]) != 0xff:
                    rowAsm.emit_op("anda", (f"#${byteCmd1[2]:02x}"), "", 2, 2, 2)
                # we don't need to write nybble with OR if we're writing 0
                if byteCmd1[1] != 0:
                    rowAsm.emit_op("ora", (f"#${byteCmd1[1]:02x}"), "", 2, 2, 2)
                if byteCmd2[0] == 1:
                    rowAsm.gen_loadstore_indexed(False, regA, regX, offX + 256*self.lineAdvance, "")  # sta off,x
                else:  # assert: byteCmd2[0] == 3
                    rowAsm.gen_loadimm_accum(regB, byteCmd2[1], "")
                    rowAsm.gen_loadstore_indexed(False, regD, regX, offX + 256* self.lineAdvance, "")  # std off,x
            elif byteCmd2[0] == 2:
                # we don't need to clear bits with AND mask if nybble we're writing is 15
                if (byteCmd2[1] | byteCmd2[2]) != 0xff:
                    rowAsm.emit_op("andb", (f"#${byteCmd2[2]:02x}"), "", 2, 2, 2)
                # we don't need to write nybble with OR if we're writing 0
                if byteCmd2[1] != 0:
                    rowAsm.emit_op("orb", (f"#${byteCmd2[1]:02x}"), "", 2, 2, 2)
                if byteCmd1[0] == 1:
                    rowAsm.gen_loadstore_indexed(False, regB, regX, offX+1 + 256*self.lineAdvance, "")  # stb off,x
                else:  # assert: byteCmd1[0] == 3
                    rowAsm.gen_loadimm_accum(regA, byteCmd1[1], "")
                    rowAsm.gen_loadstore_indexed(False, regD, regX, offX + 256*self.lineAdvance, "")  # std off,x
            else:
                raise Exception("Error: word in cmdWordsToStore contains no Command-2 bytes!")
        # assert that only command3 bytes/words are remaining to be written, and all bytes/words have been stored
        if len(cmdBytesToStore) > 0 or len(cmdWordsToStore) > 0:
            raise Exception("internal error: unstored bytes/words remaining!");
        for (offX,offY,byteCmd) in cmdBytesToWrite:
            if byteCmd[0] != 3:
                raise Exception(f"internal error: command-{int(byteCmd[0])} byte to write")
        for (offX,offY,byteCmd1,byteCmd2) in cmdWordsToWrite:
            if byteCmd1[0] != 3 or byteCmd2[0] != 3:
                raise Exception(f"internal error: command-({int(byteCmd1[0])},{int(byteCmd2[0])}) bytes to write in word")
        # emit byte writes for any bytes which match our current register values
        if rowAsm.reg.IsValid(regA) or rowAsm.reg.IsValid(regB):
            idx = 0
            while idx < len(cmdBytesToWrite):
                (offX,offY,byteCmd) = cmdBytesToWrite[idx]
                matchReg = None
                if rowAsm.reg.IsValid(regA) and byteCmd[1] == rowAsm.reg.GetValue(regA):
                    matchReg = regA
                elif rowAsm.reg.IsValid(regB) and byteCmd[1] == rowAsm.reg.GetValue(regB):
                    matchReg = regB
                if matchReg == None:
                    idx += 1
                    continue
                # we found a match.  Write 2 pixels
                rowAsm.gen_loadstore_indexed(False, matchReg, regX, offX + 256*self.lineAdvance, "")
                # pop this byte command out of the Write list, and reiterate with the same idx to get the next byte command
                cmdBytesToWrite.pop(idx)
        # make lists of unique byte and word values to write
        uniqByteValues = []
        uniqWordValues = []
        for (offX,offY,byteCmd) in cmdBytesToWrite:
            val = byteCmd[1]
            if val not in uniqByteValues:
                uniqByteValues.append(val)
        for (offX,offY,byteCmd1,byteCmd2) in cmdWordsToWrite:
            val = (byteCmd1[1] << 8) + byteCmd2[1]
            if val not in uniqWordValues:
                uniqWordValues.append(val)
        # permute across all orderings of word writes to minimize number of loads
        score,wordOrder = self.PermuteWordWriteOrder(rowNum, rowAsm.reg, uniqWordValues, [ ])
        # we need a scratch register to use while writing bytes that don't match words
        # choose one which doesn't destroy a useful register for the first word
        if not rowAsm.reg.IsValid(regA):
            scratchReg = regA
        elif not rowAsm.reg.IsValid(regB):
            scratchReg = regB
        else:
            scratchReg = regB
            if len(wordOrder) > 0 and (wordOrder[0] & 0xff) == rowAsm.reg.GetValue(regB):
                scratchReg = regA
        # make list of byte values to write which don't match any bytes in any word
        lonelyByteVals = [ ]
        for (offX,offY,byteCmd) in cmdBytesToWrite:
            matchWord = False
            for (offXW, offYW, byteCmd1W, byteCmd2W) in cmdWordsToWrite:
                if byteCmd[1] == byteCmd1W[1] or byteCmd[1] == byteCmd2W[1]:
                    matchWord = True
            # if this byte doesn't match any words to write, add it to lonely byte list
            if not matchWord and byteCmd[1] not in lonelyByteVals:
                lonelyByteVals.append(byteCmd[1])
        # fixme (micro-op): if len(cmdWordsToWrite) == 0, then search in lonelyByteVals for a byte
        # which may be written in the following row.  If found, put at end of lonelyByteVals list
        # emit byte writes for those bytes which don't match any bytes in any word
        for lonelyVal in lonelyByteVals:
            rowAsm.gen_loadimm_accum(scratchReg, lonelyVal, "")
            idx = 0
            while idx < len(cmdBytesToWrite):
                (offX,offY,byteCmd) = cmdBytesToWrite[idx]
                # if this byte to write doesn't match the lonely byte value we're writing, then skip it
                if byteCmd[1] != lonelyVal:
                    idx += 1
                    continue
                # otherwise we will emit this byte write now
                rowAsm.gen_loadstore_indexed(False, scratchReg, regX, offX + 256*self.lineAdvance, "")
                # pop this byte command out of the Write list, and reiterate with the same idx to get the next byte command
                cmdBytesToWrite.pop(idx)
        # emit all words write (and matching byte writes)
        while len(cmdWordsToWrite) > 0:
            # pop command and write the word
            (offXW, offYW, byteCmd1W, byteCmd2W) = cmdWordsToWrite.pop(0)
            loadA = (not rowAsm.reg.IsValid(regA)) or (byteCmd1W[1] != rowAsm.reg.GetValue(regA))
            loadB = (not rowAsm.reg.IsValid(regB)) or (byteCmd2W[1] != rowAsm.reg.GetValue(regB))
            if loadA and loadB:
                wordVal = (byteCmd1W[1] << 8) + byteCmd2W[1]
                rowAsm.gen_loadimm_accum(regD, wordVal, "")
            elif loadA:
                rowAsm.gen_loadimm_accum(regA, byteCmd1W[1], "")
            elif loadB:
                rowAsm.gen_loadimm_accum(regB, byteCmd2W[1], "")
            rowAsm.gen_loadstore_indexed(False, regD, regX, offXW + 256*self.lineAdvance, "")  # std off,x
            # write any matching bytes
            idx = 0
            while idx < len(cmdBytesToWrite):
                (offX,offY,byteCmd) = cmdBytesToWrite[idx]
                matchReg = None
                if byteCmd[1] == rowAsm.reg.GetValue(regA):
                    matchReg = regA
                elif byteCmd[1] == rowAsm.reg.GetValue(regB):
                    matchReg = regB
                if matchReg == None:
                    idx += 1
                    continue
                # we found a match.  Write 2 pixels
                rowAsm.gen_loadstore_indexed(False, matchReg, regX, offX + 256*self.lineAdvance, "")
                # pop this byte command out of the Write list, and reiterate with the same idx to get the next byte command
                cmdBytesToWrite.pop(idx)
        # assert that there is nothing left to do
        if len(cmdBytesToWrite) != 0:
            raise Exception("Error: remaining cmdBytesToWrite after everything is done!")
        if len(cmdWordsToWrite) != 0:
            raise Exception("Error: remaining cmdWordsToWrite after everything is done!")
        # return the generated assembly language code
        return rowAsm

    def PermuteWordWriteOrder(self, rowNum, regState, uniqWordValues, wordOrder):
        # if we are at a leaf, calculate the score and return
        if len(uniqWordValues) == 0:
            score = 0.0
            if len(wordOrder) > 0:
                # give 1 point if a byte in the first word matches up with an existing regA/regB known value
                firstWordWriteVal = wordOrder[0]
                if regState.IsValid(regA) and regState.GetValue(regA) == (firstWordWriteVal >> 8):
                    score += 1.0
                elif regState.IsValid(regB) and regState.GetValue(regB) == (firstWordWriteVal & 0xff):
                    score += 1.0
                # increase the score by the probability that this word (or a sub-byte) will be useful to the next row
                lastVal = wordOrder[-1]
                if rowNum < self.height - 1:
                    wordWriteProb = self.wordWriteProbByRow[rowNum+1]
                    byteWriteProb = self.byteWriteProbByRow[rowNum+1]
                    if lastVal in wordWriteProb:
                        score += wordWriteProb[lastVal]
                    byteProb = 0.0
                    if (lastVal >> 8) in byteWriteProb:
                        byteProb = byteWriteProb[lastVal >> 8]
                    if (lastVal & 0xff) in  byteWriteProb:
                        byteProb = max(byteProb, byteWriteProb[lastVal & 0xff])
                    score += byteProb
            # give 1 point for each byte load that we can avoid when advancing to next word to write
            for idx in range(len(wordOrder)-1):
                if (wordOrder[idx] & 0xff00) == (wordOrder[idx+1] & 0xff00):
                    score += 1.0
                if (wordOrder[idx] & 0xff) == (wordOrder[idx+1] & 0xff):
                    score += 1.0
            return (score,copy.copy(wordOrder))
        # otherwise, try all possible orderings and keep track of the one with the best score
        bestScore = 0
        bestOrder = None
        for idx in range(len(uniqWordValues)):
            nextWord = uniqWordValues.pop(idx)
            wordOrder.append(nextWord)
            tryScore,tryOrder = self.PermuteWordWriteOrder(rowNum, regState, uniqWordValues, wordOrder)
            if bestOrder == None or tryScore > bestScore:
                bestScore = tryScore
                bestOrder = tryOrder
            wordOrder.pop()
            uniqWordValues.insert(idx, nextWord)
        return (bestScore, bestOrder)


# *************************************************************************************************
# Application object: high-level processing, statistics gathering, final assembly dump
# *************************************************************************************************

class App:
    def __init__(self, spriteFilename, asmFilename):
        self.spriteFilename = spriteFilename
        self.asmFilename = asmFilename
        self.spriteList = []
        self.groupNumber = None

    def ReadInput(self):
        curSprite = None
        spritetext = open(self.spriteFilename).read()
        for line in spritetext.split("\n"):
            # remove comments and whitespace from line
            pivot = line.find("*")
            if pivot != -1:
                line = line[:pivot]
            line = line.strip()
            if len(line) < 1:
                continue
            if line[0] == '[' and line[-1] == ']':
                # new sprite definiton
                if curSprite != None:
                    curSprite.FinishDefinition()
                newSpriteName = line[1:-1]
                curSprite = Sprite(newSpriteName)
                self.spriteList.append(curSprite)
                continue
            if curSprite == None:
                pivot = line.find('=')
                if pivot != -1:
                    key = line[0:pivot].strip().lower()
                    value = line[pivot+1:].strip()
                    if key == "group":
                        self.groupNumber = int(value)
                        continue
                print(f"Warning: ignore line before sprite section: {line}")
                continue
            curSprite.ReadInputLine(line)
        if curSprite != None:
            curSprite.FinishDefinition()

    def PrintRow(self, RowName, Values, datatype):
        if len(RowName) < 16:
            RowName += " " * (16 - len(RowName))
        else:
            RowName = RowName[:16]
        print(RowName, end=' ')
        for val in Values:
            if val == None:
                s = ""
            elif datatype == str:
                s = val
            elif datatype == int:
                s = str(val)
            elif datatype == float:
                s = f"{val:.2f}"
            else:
                raise Exception("Invalid data type")
            if len(s) >= 8:
                print(s[:8], end=' ')
            else:
                print(" " * (8 - len(s)) + s, end=' ')
        print()

    def Calculate(self):
        for sprite in self.spriteList:
            sprite.Process1_PreCalc()
            sprite.Process2_GenErase()
            sprite.Process3_GenDraw(0)
            if sprite.hasSinglePixelPos:
                sprite.Process3_GenDraw(1)
        # calculate and print statistics for each sprite
        Names = []
        Pixels = []
        Storage = []
        MaxCycles = []
        CyclesPerPix = []
        EraseBytes = []
        EraseCycles = []
        DrawLBytes = []
        DrawLCycles = []
        DrawRBytes = []
        DrawRCycles = []
        TotalErase = 0
        TotalDrawL = 0
        TotalDrawR = 0
        # add data to lists
        for sprite in self.spriteList:
            name = sprite.name
            # skip blank sprites
            if sprite.numPixels == 0:
                continue
            Names.append(name)
            Pixels.append(sprite.numPixels)
            Storage.append(sprite.numSavedBytes)
            EraseBytes.append(sprite.funcErase.metrics.bytes)
            EraseCycles.append(sprite.funcErase.metrics.cycles)
            DrawLBytes.append(sprite.funcDraw[0].metrics.bytes)
            DrawLCycles.append(sprite.funcDraw[0].metrics.cycles)
            if sprite.hasSinglePixelPos:
                DrawRBytes.append(sprite.funcDraw[1].metrics.bytes)
                DrawRCycles.append(sprite.funcDraw[1].metrics.cycles)
                MaxDrawCycles = max(sprite.funcDraw[0].metrics.cycles, sprite.funcDraw[1].metrics.cycles)
            else:
                DrawRBytes.append(None)
                DrawRCycles.append(None)
                MaxDrawCycles = sprite.funcDraw[0].metrics.cycles
            myMaxCycles = MaxDrawCycles + sprite.funcErase.metrics.cycles
            MaxCycles.append(myMaxCycles)
            CyclesPerPix.append(float(myMaxCycles) / float(sprite.numPixels))
            TotalErase += sprite.funcErase.metrics.bytes
            TotalDrawL += sprite.funcDraw[0].metrics.bytes
            if sprite.hasSinglePixelPos:
                TotalDrawR += sprite.funcDraw[1].metrics.bytes
        # print summary
        numSprites = len(self.spriteList)
        print(f"Total number of sprites: {int(numSprites)}")
        print(f"Total Erase code bytes: {int(TotalErase)}")
        print(f"Total Draw Left code bytes: {int(TotalDrawL)}")
        print(f"Total Draw Right code bytes: {int(TotalDrawR)}")
        print()
        # last column should be averages
        Names.append("Average")
        Pixels.append(sum(Pixels) / numSprites)
        Storage.append(sum(Storage) / numSprites)
        MaxCycles.append(sum(MaxCycles) / numSprites)
        CyclesPerPix.append(sum(CyclesPerPix) / float(numSprites))
        EraseBytes.append(sum(EraseBytes) / numSprites)
        EraseCycles.append(sum(EraseCycles) / numSprites)
        DrawLBytes.append(sum(DrawLBytes) / numSprites)
        DrawLCycles.append(sum(DrawLCycles) / numSprites)
        ValidDrawRBytes = [val for val in DrawRBytes if val is not None]
        ValidDrawRCycles = [val for val in DrawRCycles if val is not None]
        if len(ValidDrawRBytes) > 0:
            DrawRBytes.append(sum(ValidDrawRBytes) / len(ValidDrawRBytes))
            DrawRCycles.append(sum(ValidDrawRCycles) / len(ValidDrawRCycles))
        # print tables
        numCols = len(Names)
        for startIdx in range(0, numCols, 8):
            endIdx = min(startIdx+8, numCols);
            self.PrintRow("Sprite Name", Names[startIdx:endIdx], str)
            self.PrintRow("Pixels", Pixels[startIdx:endIdx], int)
            self.PrintRow("Storage Bytes", Storage[startIdx:endIdx], int)
            self.PrintRow("Max Cycles", MaxCycles[startIdx:endIdx], int)
            self.PrintRow("Cycles/pixel", CyclesPerPix[startIdx:endIdx], float)
            print("**************Erase:")
            self.PrintRow("Code bytes", EraseBytes[startIdx:endIdx], int)
            self.PrintRow("Clock cycles", EraseCycles[startIdx:endIdx], int)
            print("**********Draw_Left:")
            self.PrintRow("Code bytes", DrawLBytes[startIdx:endIdx], int)
            self.PrintRow("Clock cycles", DrawLCycles[startIdx:endIdx], int)
            if len(ValidDrawRBytes) > 0:
                print("*********Draw_Right:")
                self.PrintRow("Code bytes", DrawRBytes[startIdx:endIdx], int)
                self.PrintRow("Clock cycles", DrawRCycles[startIdx:endIdx], int)
            print()

    def WriteAsm(self):
        # make sure we have a group number
        if self.groupNumber == None:
            raise Exception(f"No group number was given in input file {self.spriteFilename}")
        # open output file for writing
        f = open(self.asmFilename, "w")
        origin = 0
        # dump out the draw/erase routines
        bHasDrawRight = False
        for sprite in self.spriteList:
            # drawLeft
            length = sprite.funcDraw[0].metrics.bytes
            f.write(f"* (Origin: ${origin:04X}  Length: {int(length)} bytes)\n")
            f.write(sprite.funcDraw[0].text + "\n")
            origin += length
            # drawRight
            if sprite.hasSinglePixelPos:
                length = sprite.funcDraw[1].metrics.bytes
                f.write(f"* (Origin: ${origin:04X}  Length: {int(length)} bytes)\n")
                f.write(sprite.funcDraw[1].text + "\n")
                origin += length
                bHasDrawRight = True
            # erase
            length = sprite.funcErase.metrics.bytes
            f.write(f"* (Origin: ${origin:04X}  Length: {int(length)} bytes)\n")
            f.write(sprite.funcErase.text + "\n")
            origin += length
        # at the end, write the Sprite Descriptor Table
        f.write(f"\nNumberOfSprites\n            fcb         {int(len(self.spriteList))}\n")
        f.write("SpriteDescriptorTable\n")
        for sprite in self.spriteList:
            f.write(f"            * {sprite.name}\n")
            p = str(sprite.width)
            f.write(f"            fcb         {p}{' ' * (24 - len(p))}* width\n")
            p = str(sprite.height)
            f.write(f"            fcb         {p}{' ' * (24 - len(p))}* height\n")
            p = str((sprite.originXcode - sprite.originXsprite)//2)
            f.write(f"            fcb         {p}{' ' * (24 - len(p))}* offsetX\n")
            p = str(-sprite.hotspot[1])
            f.write(f"            fcb         {p}{' ' * (24 - len(p))}* offsetY\n")
            f.write("            fcb         0                       * cpLeft\n")
            f.write("            fcb         0                       * cpRight\n")
            f.write("            fcb         0                       * cpErase\n")
            p = str(sprite.numSavedBytes)
            f.write(f"            fdb         {p}{' ' * (24 - len(p))}* storeBytes\n")
            p = str(sprite.funcDraw[0].metrics.bytes)
            f.write(f"            fdb         {p}{' ' * (24 - len(p))}* length of drawLeft in bytes\n")
            if sprite.hasSinglePixelPos:
                p = str(sprite.funcDraw[1].metrics.bytes)
                f.write(f"            fdb         {p}{' ' * (24 - len(p))}* length of drawRight in bytes\n")
            else:
                f.write("            fdb         0                       * length of drawRight in bytes\n")
            p = str(sprite.funcErase.metrics.bytes)
            f.write(f"            fdb         {p}{' ' * (24 - len(p))}* length of erase in bytes\n")
            f.write("            fcb         0                       * res1\n")

# *************************************************************************************************
# main function for standard script execution
# *************************************************************************************************

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <InputSpriteFile> <OutputAsmFile> <6809 | 6309>")
        sys.exit(1)
    # set CPU type
    global CPU
    CPU = int(sys.argv[3])
    # run the app
    myApp = App(sys.argv[1], sys.argv[2])
    myApp.ReadInput()
    myApp.Calculate()
    myApp.WriteAsm()


