.global _start

.equ SYS_READ, 3
.equ SYS_WRITE, 4
.equ SYS_EXIT, 1
.equ SYS_GETTIME, 0x4E
.equ STDOUT, 1
.equ STDIN, 0

@ Game control loop (between _start: and _exit:)
@ Register usage:
@ R8: generated random number
@ R9: guesses remaining
_start:
        BL    gen_number

        MOV   R8, R0            @ Store 'hidden' number in R8
        MOV   R9, #9            @ Initialise remaining guesses to 9
        LDR   R1, =new_game     @ Load new game string
        MOV   R2, #new_game_len @ Load new game string length
        BL print             @ Print the new game string
next_guess:
        LDR   R1, =prompt       @ Load prompt string address
        MOV   R2, #prompt_len   @ Load prompt length
        BL read            @ Print the prompt

        LDR   R1,  =input       @ TASK: Load input buffer address
        MOV   R2,  #3           @ TASK: Load input buffer length
        BL print               @ Read 3 chars to input buffer (including newline)

        BL    atoxnum           @ Convert string to integer.
        MOV   R1, R8            @ Copy hidden number
        MOV   R10, R0           @ Backup guessed number
        BL    print_hint        @ Print a hint

        CMP   R10, R8           @ If the guess was correct,
        BEQ   _exit             @   Exit
        SUBS  R9, #1            @ Reduce the remaining guesses (!)
        BGT   next_guess        @ Try next guess if available
        MOV   R0, R8            @ Pass 'hidden' number as argument.
        BL    print_lose        @ No guess remaining, you lose.
_exit:
        MOV R7, #SYS_EXIT       @ exit syscall
        SWI 0

@ Functions

@@@@ Print a string on monitor
@ Parameters:
@   R1: address of string
@   R2: length of string
@ Returns:
@   none
print:                      
    STMFD SP!, {R7,LR}      @ Push used registers and LR on the stack;
    MOV R7, #SYS_WRITE 				@ TASK: Put the Syscall number in R?
    MOV R0, #STDOUT         		@ TASK: Put the monitor Stdout in R?
    SWI 0                   @ TASK: Uncomment this line to make the syscall
    LDMFD SP!, {R7,LR}      @ Restore used registers (update SP with !)
    BX LR                 @ Return

@@@@ Read  a string from keyboard
@ Parameters:
@   R1: address of where to store string
@   R2: number of characters to store
@ Returns:
@   none
read:
    STMFD SP!, {R7, LR}     @ Push used registers and LR to stack
    MOV R7, #SYS_READ              @ TASK: Put the Syscall number in R?
    MOV R0, #STDIN              @ TASK: Put the keyboard Stdin in R?
    SWI 0                   @ TASK: Uncomment this line to make the syscall
    LDMFD SP!, {R7, LR}     @ Restore used registers (update SP with !)
    BX LR



@@@@ atoxnum: convert the ASCII hex characters in input to a number
@ Parameters: 
@   R1: address of ASCII representation
@ Returns: 
@   R0: calculated value
atoxnum:  STMFD SP!, {R4-R5, LR}@ TASK: Explain why this push occurs
          MOV   R4, #0          @ character count: find out where the newline is
          MOV   R5, #0          @ number entered in hex
nextchar: LDRB  R0, [R1,R4]     @ load byte from address R1 + R4
          CMP   R0, #0xA        @ TASK: Explain the purpose of this line of code
          BEQ   readall         @ done reading
          BL    atox            @ convert to hex
          CMP   R4, #1          @ is this the first character read?
          BLT   first
                                @ shift R5 4 bits to the left
          MOV   R5, R5, LSL #4  @(most significant digit)
                                @ TASK: Explain why (in the above) we perfom a shift
first:    ADD   R5, R0          @ add R0
          ADD   R4, #1          @ increment counter
          BAL   nextchar
readall:  MOV   R0, R5
          LDMFD SP!, {R4-R5, LR}
          BX LR

@@@@ numtoasc: Convert the number to a hexadecimal ASCII string
@ Parameters: 
@   R0: value to convert
@   R1: address of string
@ Returns:
@   none
numtoasc: STMFD SP!, {R4, LR}   @ TASK: Explain why this push occurs
          MOV   R4, R0          @ copy number
          AND   R0, #0xF0       @ mask off ms-nibble
          MOV   R0, R0, LSR #4  @ shift to right
          BL    xtoa            @ convert to ASCII
          STRB  R0, [R1]        @ store byte at R1
          MOV   R0, R4          @ reload R0
          AND   R0, #0xF        @ mask off ls-nibble
          BL    xtoa            @ convert to ASCII
          STRB  R0, [R1, #1]    @ store 2nd character
          MOV   R0, #0xA        @ newline
          STRB  R0, [R1, #2]    @ store at end of string
          LDMFD SP!, {R4, LR}
          BX LR

@@@@ atox: Convert ASCII hex character to its integer value
@ Parameters: 
@   R0: ASCII character (assumed '0'-'9', 'A'-'F' or 'a'-'f')
@ Returns:
@   R0: Integer value of provided character
atox:
    CMP    R0, #0x40   @ Compare with the character smaller than 'A/a'
    SUBLT  R0, #0x30   @ If in range 0-9, substract '0'
    ORRGT  R0, #0x60   @ If in range A-F or a-f, force lower case ...
    SUBGT  R0, #0x57   @    and substract 'a'-10
    BX LR
@                      TASK: Add a comment regarding SUB vs SUBLT
@ SUBLT is only done if status flags show that the previous result is less than zero (or negative)
@ In this case the previous line sets the negative flag only when R0 is in the range 0-9.
@                      TASK: Add a comments to give 2 examples
@                            of the case conversion
@ Example 1
@ Register R0 contains:                             A
@ The hexadecimal ASCII code is :                   0x41
@ In binary this is :                               1000001
@ The hexadecimal ASCII code 0x40 in binary is:     1000000      
@ 1000001 - 1000000 > 0, therefore the negative flag is not set.
@ The line (SUBLT  R0, #0x30) is skipped       
@ The line (ORRGT  R0, #0x60) forces A to a:        0x61
@ In binary this is :                               1100001
@ 0x57 in binary is:                                1010111
@ 1100001 - 1010111 = 01010 (97 - 87 = 10)
@ The final result in binary is :                   01010

@ Example 2
@ Register R0 contains:                             B
@ The hexadecimal ASCII code is :                   0x42
@ In binary this is :                               1000010
@ The hexadecimal ASCII code 0x40 in binary is:     1000000      
@ 1000010 - 1000000 > 0, therefore the negative flag is not set.
@ The line (SUBLT  R0, #0x30) is skipped       
@ The line (ORRGT  R0, #0x60) forces B to b:        0x62
@ In binary this is :                               1100010
@ 0x57 in binary is:                                1010111
@ 1100010 - 1010111 = 01011 (98 - 87 = 11)
@ The final result in binary is :                   01011

@@@@ xtoa: Convert integer value to ASCII hex character
@ Parameters: 
@   R0: integer value in range 0-15
@ Returns:   
@   R0: related ASCII character ('0'-'9', 'A'-'F')
xtoa:
    CMP    R0, #9      @ Compare to 9
                       @ TASK: If <= (i.e. 0 to 9), add '0'
    ADDLT  R0, #0x30   @ If in range 0-9, add '0'
                       @ TASK: If > (i.e. 10-15), add 'A'-10
    ADDGT  R0, #0x57   @ And add 'a'-10
    BX LR
@                       TASK: Add a comment to give 2 examples of 
@                             the conversion

@ Example 1
@ Register R0 contains:                             1 
@ 1 - 9 < 0, therefore the negative flag is set.
@ The line (ADD  R0, #0x30) is carried out:
@ 1 + 0 = 1                                         #0x31     
@ The line (ADDGT  R0, #0x57) is skipped.
@ The final result in hex is :                      #0x31

@ Example 2
@ Register R0 contains:                             10 
@ 10 - 9 > 0, therefore the negative flag is not set.
@ The line (ADD  R0, #0x30) is skipped.     
@ The line (ADDGT  R0, #0x57) is carried out:    
@ a in binary is:      01100001
@ 10 in binary is      00001010
@ 10 + (a - 10) = a                                 01100001
@ 01100001 in hex is                                #0x61      
@ The final result in hex is :                      #0x61

@@@@ gen_number: Generate a number based on the current time
@ Parameters :
@   none
@ Returns:  
@   R0: 7-bit 'random' value
gen_number:
    STMFD  SP!, {R1,R7,LR}
@   MOV    R0, #30       @ TASK: This function will be written later
                         @ for now we will return a fixed value
    LDR R0, =time
    MOV R1, #0
    MOV R7, #SYS_GETTIME
    SWI 0
@ Task 3, the numer of seconds since Jan 1 1970 in binary
    LDR R1, =musecs
    STR R0, [R1, #1]
    AND R0, #0x7F

    LDMFD  SP!, {R1,R7,LR}
    BX LR

@@@@ print_hint : indicate whether the number is higher, lower or correct.
@ Parameters: 
@   R0: guessed value
@   R1: 'hidden' random value
@ Returns:
@   none
print_hint:
    STMFD  SP!, {R1-R2,LR}
    CMP    R1, R0             @ Compare hidden and guessed value
    LDREQ  R1, =congrats      @ If equal, select congrats ...
    MOVEQ  R2, #congrats_len  @   ... and its length
    LDRLT  R1, =lower         @ If less than, select lower
    MOVLT  R2, #lower_len
    LDRGT  R1, =higher         @ If greater than, select higher
    MOVGT  R2, #higher_len
    BL     print              @ Print that was selected.
    LDMFD  SP!, {R1-R2,LR}
    BX LR

@@@@ print_lose : reveal the hidden number
@ Parameters: 
@   R0: 'hidden' random value
@ Returns:
@   none
print_lose:
    STMFD  SP!, {R1-R2, LR}
    LDR    R1, =lostgame      @ Load 'lost-game' string buffer reference
    ADD    R1, #value_offset  @ Adjust to the position of the number
    BL     numtoasc           @ Write hidden value to buffer
    LDR    R1, =lostgame      @ Restore buffer reference
    MOV    R2, #lostgame_len  @ ... and its length
    BL     print              @ Print string with the number
    LDMFD  SP!, {R1-R2, LR}
    BX LR

@ In the .data section
.data

prompt:           .asciz  "Guess a number between 0 and 0x7F\n"
.equ              prompt_len, 34
higher:           .asciz  "Higher\n"
.equ              higher_len, 7
lower:            .asciz  "Lower\n"
.equ              lower_len, 6
congrats:         .asciz  "Congrats, you guessed it\n"
.equ              congrats_len, 25
new_game:         .asciz  "You have 9 attempts to guess\n"
.equ              new_game_len, 29
lostgame:         .asciz  "You lose, the number was 00\n"
.equ              lostgame_len, 28
.equ              value_offset, 25  @ index into the lostgame 
                                    @ string so the number
                                    @ can be written into it.

@Variables
input:            .space 3      @ TASK: Create user guess variable here
time:             .space 4      @ Time (s) since Jan 1 1970
musecs:           .space 4      @ Time (ms)
