#!/usr/bin/env python
#********************************************************************************
# DynoSprite - scripts/symbol-extract.py
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

#******************************************************************************
# main function call for standard script execution
#

if __name__ == "__main__":
    print "Symbol Extractor Script"
    if len(sys.argv) != 3:
        print "    Usage: %0 <input.lst> <output.asm>"
        sys.exit(1)
    # parse input list and extract all global symbols
    bFoundSymTable = False
    SymList = [ ]
    f = open(sys.argv[1], "r").read()
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
            SymList.append((symdef[0], int(symdef[1], 16)))
    # write tile directory table to include in DynoSprite core
    f = open(sys.argv[2], "w")
    for sym in SymList:
        f.write(sym[0]+ (" " * (36 - len(sym[0]))) + ("EQU $%04x" % sym[1]) + "\n")
    f.close()


