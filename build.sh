nasm -f elf64 -g -F dwarf -o "$1".o "$1".asm
ld "$1".o -o "$1"
