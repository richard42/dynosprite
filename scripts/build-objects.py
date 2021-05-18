#!/usr/bin/env python3
#********************************************************************************
# DynoSprite - scripts/build-object.py
# Copyright (c) 2013, Richard Goedeken
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
import re
import sys
from compression import *

class Group:
    def __init__(self, number):
        self.GrpNumber = number
        self.SprSymbols = None
        self.ObjSymbols = None
        self.SprRaw = None
        self.ObjRaw = None
        self.numSprites = 0
        self.numObjects = 0
        self.objCodeLength = 0
        self.rawData = None
    def parseInputs(self):
        # validate symbol tables
        if not 'NumberOfSprites' in self.SprSymbols:
            print(f"****Error: Missing NumberOfSprites in sprite group {int(self.GrpNumber)}")
            sys.exit(1)
        if not 'SpriteDescriptorTable' in self.SprSymbols:
            print(f"****Error: Missing SpriteDescriptorTable in sprite group {int(self.GrpNumber)}")
            sys.exit(1)
        if self.SprSymbols["SpriteDescriptorTable"] - self.SprSymbols["NumberOfSprites"] != 1:
            print(f"****Error: SpriteDescriptorTable should immediately follow NumberOfSprites in sprite group {int(self.GrpNumber)}")
            sys.exit(1)
        if not 'NumberOfObjects' in self.ObjSymbols:
            print(f"****Error: Missing NumberOfObjects in object group {int(self.GrpNumber)}")
            sys.exit(1)
        if not 'ObjectDescriptorTable' in self.ObjSymbols:
            print(f"****Error: Missing ObjectDescriptorTable in object group {int(self.GrpNumber)}")
            sys.exit(1)
        if self.ObjSymbols["ObjectDescriptorTable"] - self.ObjSymbols["NumberOfObjects"] != 1:
            print(f"****Error: ObjectDescriptorTable should immediately follow NumberOfObjects in object group {int(self.GrpNumber)}")
            sys.exit(1)
        # get number of sprites and objects in this group
        sdtStart = self.SprSymbols["SpriteDescriptorTable"]
        odtStart = self.ObjSymbols["ObjectDescriptorTable"]
        self.numSprites = self.SprRaw[sdtStart-1]
        self.numObjects = self.ObjRaw[odtStart-1]
        print(f"    Found {int(self.numSprites)} sprites and {int(self.numObjects)} objects in group {int(self.GrpNumber)}")
        # validate length of raw data
        if len(self.SprRaw) != sdtStart + self.numSprites * 16:
            print(f"****Error: group {int(self.grpNumber)} sprite raw code file length is wrong")
            sys.exit(1)
        if len(self.ObjRaw) != odtStart + self.numObjects * 18:
            print("****Error: group {} object raw code file length is wrong: {} {}" \
              .format(self.numObjects, len(self.ObjRaw), odtStart + self.numObjects * 16))
            sys.exit(1)
        # compress the sprite and object code, and generate output data for this group
        comp = Compressor(self.SprRaw[:sdtStart-1])
        self.compSpriteCode = comp.Deflate(bPrintInfo=False, bUseGzip=False)
        comp = Compressor(self.ObjRaw[:odtStart-1])
        self.compObjectCode = comp.Deflate(bPrintInfo=False, bUseGzip=True)
        self.rawData = self.SprRaw[sdtStart:] + self.ObjRaw[odtStart:] + self.compSpriteCode + self.compObjectCode
        # this is here to test/debug decompressor problems in 6809 code
        #open("Group%i-Sprite-Raw.dat" % self.GrpNumber, "wb").write(self.SprRaw[:sdtStart-1])
        #open("Group%i-Object-Raw.dat" % self.GrpNumber, "wb").write(self.ObjRaw[:odtStart-1])
        #open("Group%i-Sprite-Comp.dat" % self.GrpNumber, "wb").write(self.compSpriteCode)
        #open("Group%i-Object-Comp.dat" % self.GrpNumber, "wb").write(self.compObjectCode)
        self.objCodeLength = odtStart - 1

def SymbolExtract(listName):
    # parse input list and extract all global symbols
    bFoundSymTable = False
    SymDict = { }
    f = open(listName).read()
    for line in f.split("\n"):
        line = line.strip()
        # look for symbol table
        if not bFoundSymTable:
            if line == "Symbol Table:":
                bFoundSymTable = True
            continue
        # check this symbol
        if len(line) > 40 and line[0:4] == '[ G]' and line.find(".") == -1 and line.find("{") == -1:
            symdef = line[5:].split()
            SymDict[symdef[0]] = int(symdef[1], 16)

    if bFoundSymTable:
        return SymDict

    symbol_parser = re.compile('^Symbol: ([^ ]+) ([^ ]+) = ([0-9A-F]+)$')
    for line in f.split("\n"):
        line = line.strip()
        # look for symbol table
        if not bFoundSymTable:
            if line == "Symbol:":
                bFoundSymTable = True

        if not line.startswith('Symbol: '):
            continue

        # check this symbol
        match = symbol_parser.match(line)
        SymDict[match.group(1)] = int(match.group(3), 16)

    return SymDict

#******************************************************************************
# main function for standard script execution
#

if __name__ == "__main__":
    print("DynoSprite Object Builder script")
    # get input paths
    if len(sys.argv) != 5:
        print(f"****Usage: {sys.argv[0]} <in_raw_folder> <in_list_folder> <out_cc3_folder> <out_asm_folder>")
        sys.exit(1)
    rawdir = sys.argv[1]
    listdir = sys.argv[2]
    cc3dir = sys.argv[3]
    asmdir = sys.argv[4]
    # make list of sprite and object description files found
    rawlist = os.listdir(rawdir)
    listlist = os.listdir(listdir)
    spriteRawFiles = [name for name in rawlist if len(name) >= 12 and name[:6] == "sprite" and name[6:8].isdigit() and name[-4:].lower() == ".raw"]
    spriteRawFiles.sort()
    spriteListFiles = [name for name in listlist if len(name) >= 12 and name[:6] == "sprite" and name[6:8].isdigit() and name[-4:].lower() == ".lst"]
    spriteListFiles.sort()
    objectRawFiles = [name for name in rawlist if len(name) >= 12 and name[:6] == "object" and name[6:8].isdigit() and name[-4:].lower() == ".raw"]
    objectRawFiles.sort()
    objectListFiles = [name for name in listlist if len(name) >= 12 and name[:6] == "object" and name[6:8].isdigit() and name[-4:].lower() == ".lst"]
    objectListFiles.sort()
    # make sure we have same # of files in each list
    numGroups = len(spriteRawFiles)
    if len(spriteListFiles) != numGroups or len(objectRawFiles) != numGroups or len(objectListFiles) != numGroups:
        print(f"****Error: extra or missing sprite/object raw or list files in '{rawdir}'.  Make clean and try again")
        print(f"  {int(len(spriteListFiles))} spriteList files found, {int(numGroups)} expected")
        print(f"  {int(len(objectRawFiles))} object raw files found, {int(numGroups)} expected")
        print(f"  {int(len(objectListFiles))} object list files found, {int(numGroups)} expected")
        sys.exit(1)
    print(f"    Found {int(numGroups)} sprite/object groups")
    # parse input files and create groups
    allGroups = [ ]
    for i in range(numGroups):
        grpNum = int(spriteRawFiles[i][6:8])
        if int(spriteListFiles[i][6:8]) != grpNum or int(objectRawFiles[i][6:8]) != grpNum or int(objectListFiles[i][6:8]) != grpNum:
            print(f"****Error: mis-matched sprite/object group numbering in '{rawdir}'.")
            sys.exit(1)
        grp = Group(grpNum)
        grp.SprSymbols = SymbolExtract(os.path.join(listdir, spriteListFiles[i]))
        grp.ObjSymbols = SymbolExtract(os.path.join(listdir, objectListFiles[i]))
        grp.SprRaw = open(os.path.join(rawdir, spriteRawFiles[i]), "rb").read()
        grp.ObjRaw = open(os.path.join(rawdir, objectRawFiles[i]), "rb").read()
        grp.parseInputs()
        allGroups.append(grp)
    # write out the data file
    f = open(os.path.join(cc3dir, "OBJECTS.DAT"), "wb")
    for grp in allGroups:
        f.write(grp.rawData)
    f.close()
    # write tile directory table to include in DynoSprite core
    f = open(os.path.join(asmdir, "gamedir-objects.asm"), "w")
    f.write("Gamedir_Objects\n")
    s = str(len(allGroups))
    f.write((" " * 24) + "fcb     " + s + (" " * (16 - len(s))) + "* number of sprite/object groups\n")
    for grpIdx in range(numGroups):
        grp = allGroups[grpIdx]
        f.write((" " * 24) + f"* Group {int(grp.GrpNumber)}: ({spriteRawFiles[grpIdx]}, {objectRawFiles[grpIdx]})" + "\n")
        s = str(grp.GrpNumber)
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* Group number\n")
        s = str(len(grp.rawData))
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Group size on disk in bytes\n")
        s = str(grp.objCodeLength)
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Object code size in bytes\n")
        s = str(len(grp.compSpriteCode))
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Size of compressed sprite code block in bytes\n")
        s = str(len(grp.compObjectCode))
        f.write((" " * 24) + "fdb     " + s + (" " * (16-len(s))) + "* Size of compressed object code block in bytes\n")
        s = str(grp.numSprites)
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* number of sprites in group\n")
        s = str(grp.numObjects)
        f.write((" " * 24) + "fcb     " + s + (" " * (16-len(s))) + "* number of objects in group\n")
    f.close()

