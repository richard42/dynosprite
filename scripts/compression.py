#!/usr/bin/env python3
#********************************************************************************
# DynoSprite - scripts/compression.py
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

import os
import sys
import subprocess

class HuffNode:
    def __init__(self):
        self.weight = 0
        self.value = None
        self.child0 = None
        self.child1 = None

class BitReader:
    def __init__(self, inputData):
        self.inBuffer = inputData
        self.curByteIdx = 0
        self.nextBitIdx = 0
        self.curByte = inputData[0]

    def GetBits(self, numBits):
        value = 0
        for i in range(numBits):
            value |= ((self.curByte >> self.nextBitIdx) & 1) << i
            self.nextBitIdx += 1
            if self.nextBitIdx == 8:
                self.nextBitIdx = 0
                self.curByteIdx += 1
                if self.curByteIdx < len(self.inBuffer):
                    self.curByte = self.inBuffer[self.curByteIdx]
                else:
                    self.curByte = None # throw an exception if we try to read one more bit
        return value

    def GetSymbol(self, huffRoot):
        # loop until we get a symbol value
        while True:
            # get 1 bit
            newBit = ((self.curByte >> self.nextBitIdx) & 1)
            self.nextBitIdx += 1
            if self.nextBitIdx == 8:
                self.nextBitIdx = 0
                self.curByteIdx += 1
                if self.curByteIdx < len(self.inBuffer):
                    self.curByte = self.inBuffer[self.curByteIdx]
                else:
                    self.curByte = None # throw an exception if we try to read one more bit
            # traverse one level down in the tree
            if newBit == 0:
                huffRoot = huffRoot.child0
            else:
                huffRoot = huffRoot.child1
            # break out if we have arrived at a leaf
            if huffRoot.value is not None:
                return huffRoot.value
            # otherwise we will get another bit

class BitWriter:
    def __init__(self):
        self.outBuffer = b''
        self.curByte = 0
        self.nextBitIdx = 0

    def AddBits(self, numBits, value, bIsCode):
        # check to make sure input is valid
        if (value >> numBits) != 0:
            raise Exception(f"BitWriter::AddBits error: the value {int(value)} doesn't fit within {int(numBits)} bits")
        # pack the bits in our accumulator
        if bIsCode:
            for bitIdxIn in range(numBits-1,-1,-1):
                self.curByte |= ((value >> bitIdxIn) & 1) << self.nextBitIdx
                self.nextBitIdx += 1
                if self.nextBitIdx == 8:
                    self.outBuffer += bytes((self.curByte,))
                    self.curByte = 0
                    self.nextBitIdx = 0
        else:
            for i in range(numBits):
                self.curByte |= (value & 1) << self.nextBitIdx
                value >>= 1
                self.nextBitIdx += 1
                if self.nextBitIdx == 8:
                    self.outBuffer += bytes((self.curByte,))
                    self.curByte = 0
                    self.nextBitIdx = 0

    def Finalize(self):
        if self.nextBitIdx > 0:
            self.outBuffer += bytes((self.curByte,))
        self.curByte = None
        self.nextBitIdx = None

    def GetData(self):
        return self.outBuffer

class Compressor:
    def __init__(self, inputdata):
        self.inputdata = inputdata
        self.outputbitstream = BitWriter()
        # each symbol in lz77SymbolList is (LenCode, LenBits, DistCode, DistBits), where:
        #   LenCode is between 0 and 285
        #   LenBits is a tuple (NumExtraBits, ValExtraBits) or None
        #   DistCode is between 0 and 29, or None
        #   DistBits in a tuple (NumExtraBits, ValExtraBits) or None
        self.lz77SymbolList = []

    def GenerateSymbolList(self):
        inDataLen = len(self.inputdata)
        # this is an expensive operation, so use a hash table
        matchHash = { }
        # first symbol is always a byte value
        self.lz77SymbolList.append(((self.inputdata[0]), None, None, None))
        inIdx = 1
        if inDataLen >= 3:
            matchHash[self.inputdata[0:3]] = [ 0 ]
        while inIdx < inDataLen:
            # if fewer than 3 bytes remaining, then we will write literals
            if (inDataLen - inIdx) < 3:
                self.lz77SymbolList.append(((self.inputdata[inIdx]), None, None, None))
                inIdx += 1
                continue
            # search for the best string copy
            bestCopy = (0, 0)  # length, distance
            matchKey = self.inputdata[inIdx:inIdx+3]
            if matchKey in matchHash:
                matchList = matchHash[matchKey]
                for origIdx in matchList[:]:
                    if (inIdx - origIdx) > 32768:
                        matchList.remove(origIdx)
                        continue
                    i1 = origIdx
                    i2 = inIdx
                    copylen = 0
                    while i2 < inDataLen and self.inputdata[i1] == self.inputdata[i2] and copylen < 258:
                        i1 += 1
                        i2 += 1
                        copylen += 1
                    if copylen >= bestCopy[0]:
                        bestCopy = (copylen, inIdx - origIdx)
            # output a byte value if there is no good copy from here
            copylen = bestCopy[0]
            if copylen < 3:
                self.lz77SymbolList.append(((self.inputdata[inIdx]), None, None, None))
                if matchKey in matchHash:
                    matchHash[matchKey].append(inIdx)
                else:
                    matchHash[matchKey] = [ inIdx ]
                inIdx += 1
                continue
            # update our match hash table for all the intermediate bytes
            for i in range(copylen):
                if (inDataLen - inIdx - i) >= 3:
                    newKey = self.inputdata[inIdx+i:inIdx+i+3]
                    if newKey in matchHash:
                        matchHash[newKey].append(inIdx+i)
                    else:
                        matchHash[newKey] = [ inIdx+i ]
            # calculate a length code (symbol number, # of extra bits, value of extra bits)
            if copylen <= 10:
                lengthCode = 254 + copylen
                lengthBitsNum = 0
                lengthBitsVal = 0
            elif copylen == 258:  # special case
                lengthCode = 285
                lengthBitsNum = 0
                lengthBitsVal = 0
            else:
                lengthBitsNum = 1
                levelEnd = 18
                while copylen > levelEnd:
                    lengthBitsNum += 1
                    levelEnd = (levelEnd * 2) - 2
                valBase = copylen - (1 << (lengthBitsNum + 2)) - 3
                lengthCode = 261 + (lengthBitsNum * 4) + (valBase >> lengthBitsNum)
                lengthBitsVal = valBase & ((1 << lengthBitsNum) - 1)
            # calculate a distance code (symbol number, # of extra bits, value of extra bits)
            copydist = bestCopy[1]
            if copydist <= 4:
                distCode = copydist - 1
                distBitsNum = 0
                distBitsVal = 0
            else:
                distBitsNum = 1
                levelEnd = 8
                while copydist > levelEnd:
                    distBitsNum += 1
                    levelEnd *= 2
                valBase = copydist - (1 << (distBitsNum + 1)) - 1
                distCode = (distBitsNum + 1) * 2 + (valBase >> distBitsNum)
                distBitsVal = valBase & ((1 << distBitsNum) - 1)
            # output a (length, distance) string copy symbol
            self.lz77SymbolList.append((lengthCode, (lengthBitsNum, lengthBitsVal), distCode, (distBitsNum, distBitsVal)))
            # advance our current index value
            inIdx += copylen
        # output the termination code
        self.lz77SymbolList.append((256, None, None, None))   

    def GenerateHuffmanTree(self, histogram):
        # make list of 'loose' huffman nodes
        nodeList = []
        for idx in range(len(histogram)):
            if histogram[idx] > 0:
                n = HuffNode()
                n.weight = histogram[idx]
                n.value = idx
                nodeList.append(n)
        # if tree is empty (histogram is all zeros), then return a special case
        if len(nodeList) == 0:
            n = HuffNode()
            n.value = 0
            return n
        # assemble the tree
        # loop until there is only 1 node, the root
        while len(nodeList) > 1:
            if nodeList[1].weight < nodeList[0].weight:
                small = 0
                smallest = 1
            else:
                small = 1
                smallest = 0
            for idx in range(2,len(nodeList)):
                if nodeList[idx].weight < nodeList[smallest].weight:
                    small = smallest
                    smallest = idx
                elif nodeList[idx].weight < nodeList[small].weight:
                    small = idx
            n = HuffNode()
            n.weight = nodeList[smallest].weight + nodeList[small].weight
            n.child0 = nodeList[smallest]
            n.child1 = nodeList[small]
            nodeList.remove(n.child0)
            nodeList.remove(n.child1)
            nodeList.append(n)
        return nodeList[0]

    def InvertHuffNode(self, huffCodes, node, preBits, preVal):
        if node.value != None:
            huffCodes[node.value] = (preBits, preVal)
            return
        self.InvertHuffNode(huffCodes, node.child0, preBits+1, preVal*2 + 0)
        self.InvertHuffNode(huffCodes, node.child1, preBits+1, preVal*2 + 1)

    def InvertHuffmanTree(self, huffTree, maxSymbol, maxBits):
        huffCodes = [ (0,0) for i in range(maxSymbol) ]
        # handle special case
        if huffTree.value != None:
            huffCodes[huffTree.value] = (1, 0)
        else:
            # let somebody else do the work
            self.InvertHuffNode(huffCodes, huffTree, 0, 0)
        # check to make sure it's legal
        for (bits,codeval) in huffCodes:
            if bits is not None and bits > maxBits:
                raise Exception(f"Huffman tree contains codes longer than maximum allowed ({int(maxBits)})")
        return huffCodes

    def GenHuffmanCodesFromLengths(self, huffLengths):
        numCodes = len(huffLengths)
        maxLength = max(huffLengths)
        # count number of codes with each given length
        popByLength = [0] * (maxLength+1)
        for codeLength in huffLengths:
            if codeLength > 0:
                popByLength[codeLength] += 1
        # calculate the starting value for each code length
        nextVal = [0] * (maxLength+1)
        curVal = 0
        for codeLength in range(1,maxLength+1):
            curVal = (curVal + popByLength[codeLength-1]) << 1
            nextVal[codeLength] = curVal
        # now assign values for each code
        huffCodes = [ ]
        for codeLength in huffLengths:
            if codeLength == 0:
                huffCodes.append((0,0))
            else:
                huffCodes.append((codeLength,nextVal[codeLength]))
                nextVal[codeLength] += 1
        return huffCodes

    # histogram codes are 4-bit code lengths, between 0 and 15
    def CompressHistogramRLE(self, histCodes, numHistCodes):
        # handle trivial cases
        if numHistCodes < 4:
            return [ (literal,None) for literal in histCodes[:numHistCodes] ]
        histRLE = [ ]
        idx = 0
        while idx < numHistCodes:
            # can we insert a multi-zero code?
            numZeros = 0
            while idx+numZeros < numHistCodes and histCodes[idx+numZeros] == 0 and numZeros < 138:
                numZeros += 1
            if numZeros >= 11:
                histRLE.append((18, numZeros-11))
                idx += numZeros
                continue
            elif numZeros >= 3:
                histRLE.append((17, numZeros-3))
                idx += numZeros
                continue
            # can we insert a prev-copy code?
            if idx > 0:
                numCopy = 0
                prevVal = histCodes[idx-1]
                while idx+numCopy < numHistCodes and histCodes[idx+numCopy] == prevVal and numCopy < 6:
                    numCopy += 1
                if numCopy >= 3:
                    histRLE.append((16, numCopy - 3))
                    idx += numCopy
                    continue
            # nope, insert a literal code
            histRLE.append((histCodes[idx], None))
            idx += 1
        # all done
        return histRLE

    def DeflateWithGzip(self, bPrintInfo):
        # call 'gzip' to compress the input data
        args = [ b"gzip", b"-9", b"-" ]
        p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        (compData, errData) = p.communicate(self.inputdata)
        # strip the gzip headers/footer
        rawData = Decompressor.StripGZ(compData, bPrintInfo)
        return rawData

    def Deflate(self, bPrintInfo, bUseGzip):
        if bPrintInfo:
            print(f"{int(len(self.inputdata))} bytes in input file.")
        # call separate function to use GZIP if necessary
        if bUseGzip:
            outputData = self.DeflateWithGzip(bPrintInfo)
            return outputData
        # start by eliminating string redundancies converting uncompressed data to LZ77 symbol list
        self.GenerateSymbolList()
        if bPrintInfo:
            print(f"{int(len(self.lz77SymbolList))} LZ77 symbols generated")
        # now generate histograms of value/length codes and distance codes
        lenCodeHist = [ 0 for i in range(286) ]
        distCodeHist = [ 0 for i in range(30) ]
        for (lengthCode, lengthBits, distCode, distBits) in self.lz77SymbolList:
            lenCodeHist[lengthCode] += 1
            if distCode is not None:
                distCodeHist[distCode] += 1
        # generate Huffman binary trees for each of these histograms
        lenHuffTree = self.GenerateHuffmanTree(lenCodeHist)
        distHuffTree = self.GenerateHuffmanTree(distCodeHist)
        # invert the Huffman trees to get the codes by their symbols
        # each element is: (codeBits, codeValue)
        lenHuffCodes = self.InvertHuffmanTree(lenHuffTree, 286, 15)
        distHuffCodes = self.InvertHuffmanTree(distHuffTree, 30, 15)
        # now re-order the codes so that the tree can be exactly re-generated with only the lengths
        lenHuffCodes = self.GenHuffmanCodesFromLengths([lenHuffCodes[i][0] for i in range(286)])
        distHuffCodes = self.GenHuffmanCodesFromLengths([distHuffCodes[i][0] for i in range(30)])
        del lenHuffTree  # the tree is no longer correct
        del distHuffTree
        # calculate number of non-zero literal/length codes and distance codes
        numLenCodes = 286
        while lenHuffCodes[numLenCodes-1][0] == 0:
            numLenCodes -= 1
        if sum(distCodeHist) == 0:
            numDistCodes = 1
        else:
            numDistCodes = 30
            while distHuffCodes[numDistCodes-1][0] == 0:
                numDistCodes -= 1
        # now RLE compress the huffman code lengths
        lenCodeLengths = [ lenHuffCodes[i][0] for i in range(286) ]
        lenHistRLE = self.CompressHistogramRLE(lenCodeLengths, numLenCodes)
        distCodeLengths = [ distHuffCodes[i][0] for i in range(30) ]
        distHistRLE = self.CompressHistogramRLE(distCodeLengths, numDistCodes)
        # generate a histogram of the RLE codes
        rleCodeHist = [ 0 for i in range(19) ]
        for (code, extraBits) in lenHistRLE:
            rleCodeHist[code] += 1
        for (code, extraBits) in distHistRLE:
            rleCodeHist[code] += 1
        # generate a Huffman binary tree for this histogram
        rleHuffTree = self.GenerateHuffmanTree(rleCodeHist)
        # invert the Huffman trees to get the codes by their symbols
        rleHuffCodes = self.InvertHuffmanTree(rleHuffTree, 19, 7)
        # now re-order the codes so that the tree can be exactly re-generated with only the lengths
        rleHuffCodes = self.GenHuffmanCodesFromLengths([rleHuffCodes[i][0] for i in range(19)])
        del rleHuffTree
        # reorder the RLE histogram and calculate number of non-zero codes
        newOrder = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]
        rleCodeLengths = [ rleHuffCodes[i][0] for i in range(19) ]
        rleCodeLengthsReorder = [ rleCodeLengths[newOrder[i]] for i in range(19) ]
        numRleCodes = 19
        while rleCodeLengths[numRleCodes-1] == 0:
            numRleCodes -= 1
        if numRleCodes < 4:
            numRleCodes = 4
        # finally, we can start writing the compressed bitstream
        # start with the 3-bit block header
        self.outputbitstream.AddBits(1, 1, False) # we only write 1 compressed block
        self.outputbitstream.AddBits(2, 2, False) # always dynamic huffman tables
        # write the number of huffman codes in each tree
        self.outputbitstream.AddBits(5, numLenCodes-257, False)
        self.outputbitstream.AddBits(5, numDistCodes-1, False)
        self.outputbitstream.AddBits(4, numRleCodes-4, False)
        # next, give 3-bit code length for each RLE huffman code, in the special ordering
        for i in range(numRleCodes):
            self.outputbitstream.AddBits(3, rleCodeLengthsReorder[i], False)
        # now give the literal/length huffman code lengths, given via RLE symbols encoded with RLE huffman tree
        numExtraBits = [2, 3, 7]
        for (rleCode, extraBits) in lenHistRLE:
            huffCode = rleHuffCodes[rleCode]
            self.outputbitstream.AddBits(huffCode[0], huffCode[1], True)
            if rleCode >= 16:
                self.outputbitstream.AddBits(numExtraBits[rleCode-16], extraBits, False)
        # next, do the Distance huffman code lengths, via RLE symbols encoded with RLE huffman tree
        for (rleCode, extraBits) in distHistRLE:
            huffCode = rleHuffCodes[rleCode]
            self.outputbitstream.AddBits(huffCode[0], huffCode[1], True)
            if rleCode >= 16:
                self.outputbitstream.AddBits(numExtraBits[rleCode-16], extraBits, False)
        # finally, encode the LZ77 symbols
        for (lengthCode, lengthBits, distCode, distBits) in self.lz77SymbolList:
            huffCode = lenHuffCodes[lengthCode]
            self.outputbitstream.AddBits(huffCode[0], huffCode[1], True)
            if lengthBits is not None and lengthBits[0] > 0:
                self.outputbitstream.AddBits(lengthBits[0], lengthBits[1], False) # raw bits to give length for codes 265-284
            if distCode is not None:
                huffCode = distHuffCodes[distCode]
                self.outputbitstream.AddBits(huffCode[0], huffCode[1], True)
                if distBits[0] > 0:
                    self.outputbitstream.AddBits(distBits[0], distBits[1], False) # raw bits to give distance for codes 4-29
        # finalize the bitstream and return the binary data
        self.outputbitstream.Finalize()
        return self.outputbitstream.GetData()

class Decompressor:
    def __init__(self, inputdata):
        self.inputBitstream = BitReader(inputdata)
        self.outputData = b''

    @staticmethod
    def StripGZ(inputdata, bPrintInfo):
        # check data format
        if inputdata[0] != 0x1f or inputdata[1] != 0x8b or inputdata[2] != 8:
            raise Exception("This is not a GZIP format file")
        # find the start of the compressed stream
        flags = inputdata[3]
        zipIdx = 10
        if (flags & 4) != 0:
            extralen = inputdata[zipIdx] * 256 + inputdata[zipIdx+1]
            zipIdx += 2 + extralen
        if (flags & 8) != 0:
            startNameIdx = zipIdx
            while inputdata[zipIdx] != 0:
                zipIdx += 1
            zipIdx += 1
            if bPrintInfo:
                print(f"    Original .GZ filename: {inputdata[startNameIdx:zipIdx - 1]}")
        if (flags & 16) != 0:
            startCommentIdx = zipIdx
            while inputdata[zipIdx] != 0:
                zipIdx += 1
            zipIdx += 1
            if bPrintInfo:
                print(f"    Original .GZ file comment: {inputdata[startCommentIdx:zipIdx - 1]}")
        if (flags & 2) != 0:
            zipIdx += 2 # CRC
        # return just the DEFLATE stream
        return inputdata[zipIdx:-8]  # CRC32 and ISIZE are on the end

    def GenerateHuffmanTreeFromLengths(self, huffLengths):
        numCodes = len(huffLengths)
        maxLength = max(huffLengths)
        # count number of codes with each given length
        popByLength = [0] * (maxLength+1)
        for codeLength in huffLengths:
            if codeLength > 0:
                popByLength[codeLength] += 1
        # create tree root and populate first node, which is special case
        huffRoot = HuffNode()
        huffRoot.child0 = HuffNode()
        huffRoot.child1 = HuffNode()
        levelList = [huffRoot.child0, huffRoot.child1]
        # now iterate through each level, creating the tree
        for level in range(1,maxLength+1):
            # codes which are on this level go on the left side of the tree
            for codeVal in range(numCodes):
                if huffLengths[codeVal] == level:
                    thisNode = levelList.pop(0)
                    thisNode.value = codeVal
            # all remaining nodes are decision nodes and have 2 children, which go to the next level
            nextLevelList = [ ]
            for node in levelList:
                node.child0 = HuffNode()
                node.child1 = HuffNode()
                nextLevelList.append(node.child0)
                nextLevelList.append(node.child1)
            levelList = nextLevelList
        # return the root of the tree
        return huffRoot

    def Inflate(self):
        # read consecutive blocks until we complete the final one
        while True:
            # 3-bit block header
            bFinalBlock = (self.inputBitstream.GetBits(1) == 1)
            blockType = self.inputBitstream.GetBits(2)
            if blockType == 1:
                numLenCodes = 288
                numDistCodes = 32
                codeLengths = ([8] * 144) + ([9] * 112) + ([7] * 24) + ([8] * 8) + ([5] * 32)
            elif blockType == 2:
                # read in the number of (non-zero) huffman codes in each category
                numLenCodes = self.inputBitstream.GetBits(5) + 257
                numDistCodes = self.inputBitstream.GetBits(5) + 1
                numRleCodes = self.inputBitstream.GetBits(4) + 4
                # read in and generate the code length list for the RLE codes
                rleCodeOrder = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]
                rleCodeLengths = [0] * 19
                for i in range(numRleCodes):
                    rleCodeLengths[rleCodeOrder[i]] = self.inputBitstream.GetBits(3)
                # generate the RLE code huffman tree
                rleHuffTree = self.GenerateHuffmanTreeFromLengths(rleCodeLengths)
                # decompress the huffman code lengths for Literal/Length and Distance trees
                totalCodeLengths = numLenCodes + numDistCodes
                codeLengths = [ ]
                while len(codeLengths) < totalCodeLengths:
                    rleSymbol = self.inputBitstream.GetSymbol(rleHuffTree)
                    if rleSymbol < 16:
                        codeLengths.append(rleSymbol)
                    elif rleSymbol == 16:
                        lastSymbol = codeLengths[-1]
                        repeatCount = self.inputBitstream.GetBits(2) + 3
                        codeLengths.extend([lastSymbol] * repeatCount)
                    elif rleSymbol == 17:
                        repeatCount = self.inputBitstream.GetBits(3) + 3
                        codeLengths.extend([0] * repeatCount)
                    elif rleSymbol == 18:
                        repeatCount = self.inputBitstream.GetBits(7) + 11
                        codeLengths.extend([0] * repeatCount)
                    else:
                        raise Exception(f"Invalid RLE Code length symbol {int(rleSymbol)}")
                if len(codeLengths) != totalCodeLengths:
                    raise Exception("Unexpected number of literal/distance huffman code lengths extracted from compressed RLE symbols")
            else:
                raise Exception(f"Unsupported DEFLATE block type {int(blockType)}")
            # generate the literal/length and distance huffman trees
            lenHuffTree = self.GenerateHuffmanTreeFromLengths(codeLengths[:numLenCodes])
            distHuffTree = self.GenerateHuffmanTreeFromLengths(codeLengths[numLenCodes:])
            # now decompress the LZ77 symbols and reconstruct the uncompressed data
            while True:
                lenSymbol = self.inputBitstream.GetSymbol(lenHuffTree)
                # if it's a literal, add it to the output data and get next symbol
                if lenSymbol < 256:
                    self.outputData += bytes((lenSymbol,))
                    continue
                # if it's the end code, then we are done
                if lenSymbol == 256:
                    break
                # otherwise it's a copy code.  start by calculating the number of bytes to copy
                if lenSymbol < 265:
                    copylen = lenSymbol - 254
                elif lenSymbol == 285:
                    copylen = 258
                else:
                    extrabits = (lenSymbol - 261) >> 2
                    quadrant = (lenSymbol - 261) & 3
                    copylen = (4 << extrabits) + (quadrant * (1 << extrabits)) + 3 + self.inputBitstream.GetBits(extrabits)
                # then get the distance code and calculate the distance backwards to start copying
                distSymbol = self.inputBitstream.GetSymbol(distHuffTree)
                if distSymbol < 4:
                    copydist = distSymbol + 1
                else:
                    extrabits = (distSymbol - 2) >> 1
                    parity = (distSymbol - 2) & 1
                    copydist = (2 << extrabits) + (parity * (1 << extrabits)) + 1 + self.inputBitstream.GetBits(extrabits)
                # perform the copy operation
                copyIdx = len(self.outputData) - copydist
                for i in range(copylen):
                    newChar = self.outputData[copyIdx]
                    self.outputData += newChar
                    copyIdx += 1
            # process another block if this is not the last one
            if bFinalBlock:
                break
        return self.outputData

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    print("DynoSprite DEFLATE Compressor Script")
    # get input paths
    if len(sys.argv) != 4 or (sys.argv[1].lower() != 'zip' and sys.argv[1].lower() != 'gzip' and sys.argv[1].lower() != 'unzip'):
        print(f"****Usage: {sys.argv[0]} <command> <input-file> <output-file>")
        print("    <command> is either 'zip', 'gzip', or 'unzip'")
        print("    <input-file> for 'unzip' command can be in .gz format or raw compressed stream")
        sys.exit(1)
    bCompress = not (sys.argv[1].lower() == 'unzip')
    bUseGzip = (sys.argv[1].lower() == 'gzip')
    infilename = sys.argv[2]
    outfilename = sys.argv[3]
    if bCompress:
        # read the input (uncompressed) file
        ifdata = open(infilename, "rb").read()
        # set up a compressor, process the data, and write to a file
        comp = Compressor(ifdata)
        ofdata = comp.Deflate(True, bUseGzip)
        open(outfilename, "wb").write(ofdata)
        print(f"Input file was compressed from {int(len(ifdata))} bytes down to {int(len(ofdata))} bytes.")
    else:
        # read the input (compressed) file
        ifdata = open(infilename, "rb").read()
        # if this is a gzip file, strip off the header and footer
        if infilename[-3:] == ".gz":
            ifdata = Decompressor.StripGZ(ifdata, True)
        # set up a decompressor and process the data to hopefully get the original back
        decomp = Decompressor(ifdata)
        ofdata = decomp.Inflate()
        open(outfilename, "wb").write(ofdata)
        print(f"Input file was decompressed from {int(len(ifdata))} bytes to {int(len(ofdata))} bytes.")

