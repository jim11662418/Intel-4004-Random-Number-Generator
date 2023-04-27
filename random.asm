    PAGE 0                          ; suppress page headings in ASW listing file
;---------------------------------------------------------------------------------------------------------------------------------
; Copyright 2023 Jim Loos
;
; Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
; (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
; publish, distribute, sub-license, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
; so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
; OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
; IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
;---------------------------------------------------------------------------------------------------------------------------------
;
; This program continuously generates and prints 16 bit random numbers generated using the Marsaglia
; (xorshift) algorithm. The initial seed for the algorithm depends upon the time it takes the user
; to press a key when prompted. The first random number generated serves as the seed for the second 
; random number. The second random number generated serves as the seed for the third random number 
; and so on. All numbers from 1 to 65535 are generated at the same frequency. The xorshift algorithm
; never generates zero (unless the seed is zero). Since this actually a pseudo-random number generator,
; the sequence of numbers for a particular initial seed will repeat after 65535 numbers are generated 
; i.e. the period or cycle length is 2^16-1.
;
; A random number is generated from a seed as follows:
;
; Take a copy of the seed.
; Shift that copy left a certain number of bits.
; XOR the original seed and the shifted seed. The result replaces the original seed. Repeat these steps twice
; more, each time with the output of the previous step as input, but next with a right shift and finally with
; a left shift. The actual number of bits used for the 3 shifts is critical. For 16 bit generators only a few
; valid combinations exist: (7, 9, 13) and (7, 9, 8).
;
; The sequence of steps to produce a random number using the xorshift algorithm:
;  1. seed X
;  2. Y = X
;  3. Y = Y << 7
;  4. X = X XOR Y
;  5. Y = X
;  6. Y = Y >> 9
;  7. X = X XOR Y
;  8. Y = X
;  9. Y = Y << 13
; 10. X = X XOR Y
; 11. X now contains the random number

; Syntax is for the Macro Assembler AS V1.42 http://john.ccac.rwth-aachen.de:8000/as/

                cpu 4004
                
                include "bitfuncs.inc"  ; Include bit functions so that FIN can be loaded from a label (upper 4 bits of address are loped off).
                include "reg4004.inc"   ; Include 4004 register definitions.
 
; the four registers of P4 and P5 together (R8,R9,R10,R11) make up 'X'. 
X1 reg R8
X2 reg R9
X3 reg R10
X4 reg R11
; the four registers of P6 and P7 together (R12,R13,R14,R15) make up 'Y' 
Y1 reg R12
Y2 reg R13
Y3 reg R14
Y4 reg R15      

;eightbits       equ 1                   ; un-comment to print 8 bit instead of 16 bit random numbers

CR              equ 0DH
LF              equ 0AH

; I/O port addresses
SERIALPORT      equ 00H                 ; address of the serial port. the least significant bit of port 0 is used for serial output.
                
                org 0000H               ; beginning address of 2732 EPROM
                
                nop                     ; "To avoid problems with power-on reset, the first instruction at
                                        ; program address 0000 should always be an NOP." (don't know why)
reset:          fim P0,SERIALPORT
                src P0
                ldm 1
                wmp                     ; set serial output high to indicate 'MARK'

                jms newline
                jms prompt              ; print 'Press any key to start...'
                jms newline
                
wait4key:       jcn tn,checkforzero     ; step 1 - produce seed in X by continuously incrementing X until the start bit is detected...        
                inc X4
                ld X4
                jcn nz,wait4key
                inc X3
                ld X3
                jcn nz,wait4key
                inc X2
                ld X2
                jcn nz,wait4key
                inc X1
                jun wait4key            ; loop back to check for the start bit
                
checkforzero:   ld X1                   ; check to make sure that the seed is not zero
                jcn nz,generate
                ld X2
                jcn nz,generate                
                ld X3
                jcn nz,generate
                ld X4
                jcn z,reset             ; this seed is zero, go back for another try
                
generate:       jms copyXtoY            ; step 2 - copy X to Y               
                
                ldm 16-7
                xch R0
                jms shiftYleft          ; step 3 - shift Y left 7 positions
                isz R0,$-2
                
                jms xorXwithY           ; step 4 - XOR X with Y, result replaces X
                               
                jms copyXtoY            ; step 5 - copy X to Y
                
                ldm 16-9                
                xch R0
                jms shiftYright         ; step 6 - shift Y right 9 positions
                isz R0,$-2
                
                jms xorXwithY           ; step 7 - XOR X with Y, result replaces X
                
                jms copyXtoY            ; step 8 - copy X to Y
                
                ldm 16-13
                xch R0
                jms shiftYleft          ; step 9 - shift Y left 13 positions
                isz R0,$-2
                
                jms xorXwithY           ; step 10 - XOR X with Y, result replaces X. X now holds the random number
                
; to print 8 bit random numbers...
            IFDEF eightbits
                ldm 0                   ; clear P2
                xch R4
                ldm 0
                xch R5
                
; to print 16 bit random numbers...   
            ELSE
                ld X1                   ; copy the upper 8 bits of X to P2
                xch R4
                ld X2
                xch R5
            ENDIF
            
                ld X3                   ; copy the lower 8 bits of X to P3
                xch R6
                ld X4
                xch R7
                jms prnDecimal          ; print the contents of P2P3 as a decimal number                
                jms newLine
                jun generate            ; go back and generate the next random number using X as the seed

;--------------------------------------------------------------------------------------------------                
; copy contents of X to Y
;--------------------------------------------------------------------------------------------------
copyXtoY:       ld X1                   ; copy P4 to P6                 
                xch Y1
                ld X2
                xch Y2
                
                ld X3                   ; copy P5 to P7
                xch Y3
                ld X4
                xch Y4 
                bbl 0
             
;--------------------------------------------------------------------------------------------------             
; shift the value in Y right one position                
;--------------------------------------------------------------------------------------------------
shiftYright:    clc
                ld Y1                 
                rar                     ; shift Y1 right
                xch Y1
                ld Y2
                rar                     ; shift Y2 right
                xch Y2 
                ld Y3
                rar                     ; shift Y3 right
                xch Y3
                ld Y4
                rar                     ; shift Y4 right
                xch Y4
                bbl 0

;--------------------------------------------------------------------------------------------------
; shift the value in Y left one position 
;--------------------------------------------------------------------------------------------------
shiftYleft:     clc
                ld Y4
                ral                     ; shift Y4 left
                xch Y4
                ld Y3
                ral                     ; shift Y3 left
                xch Y3
                ld Y2
                ral                     ; shift Y2 left
                xch Y2
                ld Y1
                ral                     ; shift Y1 left
                xch Y1       
                bbl 0                
                
;--------------------------------------------------------------------------------------------------
; The following subroutine produces the exclusive OR of the two 4-bit quantities
; held in index registers R0 and R1. The result is placed in register R0, while register
; R1 is set to 0. Index registers R2 and R3 are also used.
;
; From the MCS-4 Assembly Language Programming Manual p.4-11
;--------------------------------------------------------------------------------------------------
xor:            fim P1,11
xor1:           ldm 0 		        ; acc = 0
                xch R0 		        ; acc = R0, R0 = acc (zero)
                ral 		        ; 1st 'xor' bit to carry
                xch R0 		        ; save shifted data in R0; acc = 0
                inc R3 		        ; done if R3 = 0
                xch R3 		        ; R3 to acc
                jcn z,xor2      	; return if acc = 0.
                xch R3 		        ; otherwise restore acc & R3
                rar 		        ; bit of R0 is alone in acc
                xch R2 		        ; save 1st xor bit in R2
                ldm 0 		        ; get bit in R1; set acc = 0
                xch R1
                ral 		        ; left bit to carry
                xch R1 		        ; save shifted data in R1
                rar 		        ; 2nd 'xor' bit to acc
                add R2 		        ; produce the xor of the bits
                ral 		        ; xor = left bit of accumulator, transmit to carry by ral.
                jun xor1
xor2:  	        bbl 0		        ; return to main program

;--------------------------------------------------------------------------------------------------
; The following subroutine produces the exclusive OR of the 16-bit quantity in X with the 16-bit
; quantity in Y by calling the XOR subroutine above 4 times (once for each of the register pairs). 
; The result is placed in X. in addition to P4, P5, P6 and P7, P0 and P1 are also used.
;--------------------------------------------------------------------------------------------------
xorXwithY:      ld X1               ; copy X1 to R0
                xch R0
                ld Y1               ; copy Y1 to R1 
                xch R1
                jms xor             ; R0 = R0 ^ R1 
                ld R0               ; copy R0 to X1
                xch X1              

                ld X2               ; copy X2 to R0
                xch R0
                ld Y2               ; copy Y2 to R1
                xch R1
                jms xor             ; R0 = R0 ^ R1
                ld R0               ; copy R0 to X2
                xch X2

                ld X3               ; copy X3 to R0
                xch R0
                ld Y3               ; copy Y3 to R1
                xch R1
                jms xor             ; R0 = R0 ^ R1
                ld R0               ; copy R0 to X3
                xch X3

                ld X4               ; copy X4 to R0
                xch R0
                ld Y4               ; copy Y4 to R1
                xch R1
                jms xor             ; R0 = R0 ^ R1
                ld R0               ; copy R0 to X4
                xch X4            
                bbl 0
                
                org 0100H
;-----------------------------------------------------------------------------------------
; prints the 16 bit contents of P2P3 (R4,R5,R6,R7) as a decimal number.
; leading zeros are suppressed.
; in addition to P2 and P3 uses P0,P1,P6 and P7.
;-----------------------------------------------------------------------------------------
prnDecimal:     ldm 0
                xch R1                  ; clear the leading zero flag (zero means do not print '0')
                
; ten thousands digit
; count the number of times 10,000 can be subtracted from the number in P2P3 before causing an underflow              
                ldm 0
                xch R0                  ; clear the digit counter
                fim P6,10000 >> 8       ; high byte of 10000
                fim P7,10000 & 0FFH     ; low byte of 10000
prnDecimal1:    jms sub16bits           ; subtract 10000 from the number in P2P3
                inc R0                  ; increment the ten thousands digit counter 
                jcn z,prnDecimal1       ; jump if no underflow
                jms add16bits           ; the previous subtraction caused an underflow, add 10000 back to P2P3
                ld R0
                dac                     ; decrement the ten thousands digit counter because of the previous underflow
                jcn z,prnDecimal2       ; do not print the ten thousands digit if it is is zero
                xch R3                  ; else, move the ten thousands digit to P1 and convert to ASCII
                ldm 3
                xch R2                 
                jms putchar             ; print the ten thousands digitt
                ldm 1
                xch R1                  ; set the leading zero flag (print all zeros from now on)

; thousands digit
; count the number of times 1000 can be subtracted from the number in P2P3 before causing an underflow   
prnDecimal2:    ldm 0
                xch R0                  ; clear the digit counter
                fim P6,1000 >> 8        ; high byte of 1000
                fim P7,1000 & 0FFH      ; low byte of 1000
prnDecimal2a:   jms sub16bits           ; subtract 1000 from the number in P2P3
                inc R0                  ; increment the thousands digit counter 
                jcn z,prnDecimal2a      ; jump if no underflow
                jms add16bits           ; the previous subtraction caused an underflow, add 1000 back to P2P3
                ld R0
                dac                     ; decrement the thousands digit counter because of the previous underflow
                xch R3                  ; move the thousands digit to P1 and convert to ASCII
                ldm 3
                xch R2   
                ld R3
                jcn nz,prnDecimal2b     ; print the thousands digit if it is not zero
                ld R1
                jcn z,prnDecimal3       ; else, skip the thousands digit if it is zero and the leading zero flag is 0
prnDecimal2b:   jms putchar             ; print the thoudands digitt
                ldm 1
                xch R1                  ; set the leading zero flag (print all zeros from now on)                

; hundreds digit...  
; count the number of times 100 can be subtracted from the number in P2P3 before causing an underflow          
prnDecimal3:    ldm 0
                xch R0                  ; clear the digit counter
                fim P6,100 >> 8         ; high byte of 100
                fim P7,100 & 0FFH       ; low byte of 100
prnDecimal3a:   jms sub16bits           ; subtract 100 from the number in P2P3
                inc R0                  ; increment the hundreds digit counter 
                jcn z,prnDecimal3a      ; jump if no underflow
                jms add16bits           ; the previous subtraction caused an underflow, add 100 back to P2P3
                ld R0
                dac                     ; decrement the hundreds digit counter because of the previous underflow
                xch R3                  ; move the hundreds digit to P1 and convert to ASCII
                ldm 3
                xch R2 
                ld R3
                jcn nz,prnDecimal3b     ; print the hundreds digit if it is not zero
                ld R1
                jcn z,prnDecimal4       ; else, skip the hundreds digit if it is zero and the leading zero flag is 0
prnDecimal3b:   jms putchar             ; print the hundreds digit
                ldm 1
                xch R1                  ; set the leading zero flag (print all zeros from now on)

; tens digit...   
; count the number of times 10 can be subtracted from the number in P2P3 before causing an underflow                        
prnDecimal4:    ldm 0
                xch R0                  ; clear the digit counter
                fim P6,10 >> 8          ; high byte of 10
                fim P7,10 & 0FFH        ; low byte of 10
prnDecimal4a:   jms sub16bits           ; subtract 10 from the number in P2P3
                inc R0                  ; increment the tens digit counter 
                jcn z,prnDecimal4a      ; jump if no underflow
                jms add16bits           ; the previous subtraction caused an underflow, add 10 back to P2P3
                ld R0
                dac                     ; decrement the tens digit counter because of the previous underflow
                xch R3                  ; move the tens digit to P1 and convert to ASCII
                ldm 3
                xch R2 
                ld R3
                jcn nz,prnDecimal4b     ; print the hundreds digit if it is not zero
                ld R1
                jcn z,prnDecimal5       ; else, skip the hundreds digit if it is zero and the leading zero flag is 0
prnDecimal4b:   jms putchar             ; print the hundreds digit
                
; units digit...   
; whatever remains in P2P3 after the subtractions above represents the units digit            
prnDecimal5:    ld R7                   ; move what remains in P2P3 to P1 and convert to ASCII
                xch R3
                ldm 3
                xch R2
                jun putchar             ; print the units digit
                bbl 0
                
;--------------------------------------------------------------------------------------------------
; Subtract the 16 bit contents of P6P7 (R12,R13,R14,R15) from the 16 bit contents of P2P3 (R4,R5,R6,R7).
; The 16 bit difference is returned in P2P3. The contents of P6P7 remain unchanged. 
; Returns 1 if underflow (the difference in P2P3 is negative).
;--------------------------------------------------------------------------------------------------
sub16bits:      ld R7
                clc   
                sub R15
                xch R7
                
                ld R6
                cmc
                sub R14
                xch R6
                
                ld R5
                cmc
                sub R13
                xch R5
                
                ld R4
                cmc
                sub R12
                xch R4
                
                jcn c,$+3
                bbl 1
                bbl 0       

;--------------------------------------------------------------------------------------------------
; Add the 16 bit contents of P6P7 (R12,R13,R14,R15) to the 16 bit contents of P2P3 (R4,R5,R6,R7).
; The 16 bit sum is returned in P2P3. The contents of P6P7 remain unchanged. 
; Returns 1 if overflow (the sum in P2P3 is greater than 65535).
;--------------------------------------------------------------------------------------------------
add16bits:      clc
                ld R7
                add R15
                xch R7

                ld R6
                add R14
                xch R6
                
                ld R5
                add R13
                xch R5
                
                ld R4
                add R12
                xch R4
                
                jcn nc,$+3
                bbl 1
                bbl 0
                
;-----------------------------------------------------------------------------------------
; print a carriage return then a line feed to position the cursor to the start of the next line
; uses P1 and P7
;-----------------------------------------------------------------------------------------
newLine:        fim P1,CR
                jms putchar
                fim P1,LF
                jun putchar
                
;--------------------------------------------------------------------------------------------------
; 9600 bps N-8-1 serial function 'putchar'
; send the character in P1 to the console serial port (the least significant bit of port 0) 
; in addition to P1 (R2,R3) also uses P7 (R14,R15)
; the character in P1 is preserved.
; adapted from Ryo Mukai's code at https://github.com/ryomuk/test4004
;--------------------------------------------------------------------------------------------------
putchar:        fim P7,SERIALPORT
                src P7                  ; set port address
                ldm 16-5
                xch R14                 ; 5 bits (start bit plus bits 0-3)
                ld R3
                clc                     ; clear carry to make the start bit
                ral
            
; send 5 bits; the start bit and bits 0-3. each bit takes 9 cycles
putchar1:       nop
                nop
                nop
                nop
                nop
                wmp
                rar
                isz R14, putchar1

                ldm 16-5                ; 5 bits (bits 4-7 plus stop bit)
                xch R14
                ld R2
                stc
                nop
                nop

; send 5 bits; bits 4-7 and the stop bit. each bit takes 10 cycles
putchar2:       wmp
                nop
                nop
                nop
                nop
                nop
                nop
                rar
                isz R14, putchar2
                bbl 0
                          
                org 0200H
;-----------------------------------------------------------------------------------------
; This function is used by all the text string printing functions. If the character in P1 is zero indicating
; the end of the string, returns with accumualtor = 0. Otherwise prints the character and increments
; P0 to point to the next character in the string then returns with accumulator = 1.
;-----------------------------------------------------------------------------------------
txtout:         ld R2                   ; load the most significant nibble into the accumulator
                jcn nz,txtout1          ; jump if not zero (not end of string)
                ld  R3                  ; load the least significant nibble into the accumulator
                jcn nz,txtout1          ; jump if not zero (not end of string)
                bbl 0                   ; end of text found, branch back with accumulator = 0

txtout1:        jms putchar             ; print the character in P1
                inc R1                  ; increment least significant nibble of pointer
                ld R1                   ; get the least significant nibble of the pointer into the accumulator
                jcn zn,txtout2          ; jump if zero (no overflow from the increment)
                inc R0                  ; else, increment most significant nibble of the pointer
txtout2:        bbl 1                   ; not end of text, branch back with accumulator = 1

;-----------------------------------------------------------------------------------------
; This function and the text it references need to be together on the same page.
;-----------------------------------------------------------------------------------------
page2print:     fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,page2print       ; go back for the next character
                bbl 0

prompt:         fim P0,lo(prompttxt)
                jun page2print

prompttxt:      data CR,LF,LF
                data "Press any key to start...",0
                end
