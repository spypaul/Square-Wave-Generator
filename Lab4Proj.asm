/******************************************************************************
* Assembly EE 244 Lab 4 Code
*	This code create a tone generater that can generate waves range from 1 to
* 2.5kHZ. There are two interface for this, switch mode and terminal mode.
* Switch mode read switch value from 1 to 16, to generate 1 to 2.4kHZ waves.
* It saturates the value to 15 if the input is over 15.
* Terminal mode ask user to enter value from 1 to 16, to generate
* 1 to 2.5kHZ waves. It also check the invalid value entered and output an error
* message.
*
* Shao-Peng Yang, 03/05/2019
******************************************************************************/
                .syntax unified        /* define Syntax */
                .cpu cortex-m4
                .fpu fpv4-sp-d16

                .globl main            /* make main() global so outside file */
                .equ SIM_SCGC5, 0x40048038 // address for the clock register
                // addresses for PORTC, port direction register, port input register, and output register
                .equ PORTC_PCR0, 0x4004B000
                .equ GPIOC_PDDR, 0x400FF094
                .equ GPIOC_PDIR, 0x400FF090
                .equ GPIOC_PDOR, 0x400FF080
                //bit maskes for later usage
                .equ BIT0, 1<<0
                .equ MUX_MASK, BIT0<<8|BIT0<<9|BIT0<<10
				.equ MUX_MASK_NEG, ~MUX_MASK
				.equ MASK_CLEAR, 0x000000FF
                .section .text         /* the following is program code      */
main:                                  /* main() is always entry point      */
                // call the subroutine to change the system clock
                bl K22FRDM_BootClock
                // pass zero thru r0 to the BIOOpen
                mov r0, #0
				bl BIOOpen
                bl InitializeIO

read:           bl SWArrayRead // getting input value from the switch
                               // the subroutine returns an 8bit integer
                // store the input value to the variable for later comparison
                ldr r1, =CurrentSW
                str r0, [r1]
                // check the input to decide which mode to go to
                cmp r0, #0
                bne switchmode

terminalmode:
                // display Message to terminal to ask for input
                ldr r0, =Message
                bl BIOPutStrg
                ldr r0, =NewLine
                bl BIOPutStrg
                //get the string input from the user
                mov r0, #3 // define the length of the string including null/enter and pass by register to r0
                ldr r1, =StgIN // r1 held the pointer for the string array and passed into the subroutine
                bl BIOGetStrg

                //check whether the string entered is one character or not
                // by checking whether the second character is a null character
                ldrb r0, [r1, #1]
                and r0, #MASK_CLEAR
                cmp r0, #0x00
                beq onechar

                //if we have two characters entered
                // we load them to different register and translate them into a integer value
                ldrb r0, [r1], #1
                and r0, #MASK_CLEAR
                ldrb r2, [r1]
                and r2, #MASK_CLEAR
                sub r0, #0x30 // translate the ascii number character to actual decimal number
                // translate the first character to tens place by multiplying by 10
                mov r1, #10
                mul r0, r1
                // translate the second character to ones place
                subs r2, #0x30
                bmi invalid // If the ones place value is negative, it might make 10*r0 +r2 fall in the valid range

                add r0, r2 // combine the two number to an integer
                // check whehter the integer is in the range from 1 to 16
                cmp r0, #1
                blo invalid
                cmp r0, #16
                bhi invalid
                b alg

onechar:        ldrb r0, [r1]
                and r0, #MASK_CLEAR
                //check whether the character is in the valid range
                cmp r0, #0x31
                blo invalid
                cmp r0, #0x39
                bhi invalid
                sub r0, #0x30//translate the character to an inetger

alg:
                // this branch determine the index for the software delay and call the output subroutine to generate waves
                bl Algorithm //r0 holds the integer value to pass in Algorithm
                add r0, #4 // add a few more cycle to make the frequency more accurate
                bl TerminalOut//r0 holds the index value to pass in TerminalOut
                b read
invalid:
                //display the invalid Message
                ldr r0, =Error
                bl BIOPutStrg
                b terminalmode


switchmode:
                // saturate the integer to 15
                usat r1, #4, r0
                mov r0, r1
                bl Algorithm//r0 holds the integer value to pass in Algorithm
                add r0, #2 //add a few more cycle to make the frequency more accurate
                bl SwitchOut//r0 holds the index value to pass in TerminalOut
                b read


/**************************************************************************
* INT8U SwArrayRead(void) – This subroutine reads the input from the switch
* and store the value as an 8bits integer into R0
*
* Params: none
* Returns: an 8 bit integer stored in r0
* MCU: K22F
* Shao-Peng Yang, 02/12/2019
**************************************************************************/
SWArrayRead:
                push {lr}
                ldr r1, =GPIOC_PDIR
                ldr r1, [r1]

                lsr r1, #2// put inputs to the far right
                ldr r2,= MASK_CLEAR
                eor r0, r1, r2// xor the inputs value with 1s, to invert them to active high
                pop {pc}
//////////////////////////////////////////////////////////////////////
/**************************************************************************
* INT9U Algorithm(INT4U) – This subroutine takes a 4 bits input value from
* 1 to 16. It has the algorithm to calculate the amount of time to call the
* the MicroSDelay to create the proper timing for the square wave.
* The algorithm is (10000/2((Input -1) +10))*micro second
*
* Params: a 4 bit integer
* Returns: a 9 bit integer stored in r0
* MCU: K22F
* Shao-Peng Yang, 03/05/2019
**************************************************************************/
Algorithm:      push {lr}
                // this is the algorithm that would determine how many microseconds the half period of the wave need
                sub r0, r0, #1
                add r0, #10
                mov r1, #10000
                udiv r0, r1, r0
                mov r1, #2
                udiv r0, r1
                pop {pc}
/////////////////////////////////////////////////////////////////////
/**************************************************************************
* void MicroSDelay(void) – This subroutine creates a micro second software
* delay when it is called
*
* Params: none
* Returns: none
* MCU: K22F
* Shao-Peng Yang, 03/05/2019
**************************************************************************/
MicroSDelay:    push {lr}
                mov r3, #35 // I used the scope to determine the value
                // a for loop to determine the software delay
delay:          subs r3, #1
                bne delay
                pop {pc}
///////////////////////////////////////////////////////////////////////
/**************************************************************************
* void SwitchOut(INT9U) – This subroutine reads the input from r0 to get
* the index value for the amount of time to call MicroSDelay
* It use bit banging technique to generate square waves with different frequency
* It keeps reading the value from the switch to check whether to return to
* the calling part
*
* Params: a 9 bits integer
* Returns: none
* MCU: K22F
* Shao-Peng Yang, 03/05/2019
**************************************************************************/
SwitchOut:      push {lr}
                push {r4,r5}
                mov r1, r0 // move the index value to r1

cloop:          mov r5, r1 // move the index value to r5 for later calculation
                           // this is a while loop depends on whether the switch value changed
delayo1:        // a for loop to create the proper delay
                bl MicroSDelay
                subs r5, #1
                bne delayo1

                // toggles the output to generate wave
                ldr r3, =GPIOC_PDOR
                ldr r4,[r3]
                eor r4, BIT0
                str r4,[r3]

                push {r1} // r1 holds the value of the index
                          // it need to be preserved
                bl SWArrayRead
                pop {r1}
                // check whether the switch value changed to terminate the wave gen
                ldr r2, =CurrentSW
                ldr r2, [r2]
                cmp r0, r2
                beq cloop
                // turn off the wave gen
                ldr r3, =GPIOC_PDOR
                mov r0, #0
                str r0,[r3]
                pop {r4,r5}
                pop {pc}
//////////////////////////////////////////////////////////////////////////
/**************************************************************************
* void TerminalOut(INT9U) – This subroutine reads the input from r0 to get
* the index value for the amount of time to call MicroSDelay
* It use bit banging technique to generate square waves with different frequency
* It waits for the 'q' charater to be enterd to return to the main part.
* If 'q' is not recieved, the subroutine would keep generating the wave
*
* Params: a 9 bits integer
* Returns: none
* MCU: K22F
* Shao-Peng Yang, 03/05/2019
**************************************************************************/
TerminalOut:    push {lr}
                push {r4,r5}
                mov r1, r0// move the index value to r1

qloop:          mov r5, r1// move the index value to r5 for later calculation
                          // this is a while loop depends on whether the 'q' character is recieved
delayo2:        // a for loop to create the proper delay
                bl MicroSDelay
                subs r5, #1
                bne delayo2
                // toggles the output to generate wave
                ldr r3, =GPIOC_PDOR
                ldr r4,[r3]
                eor r4, BIT0
                str r4,[r3]

                push {r1, r3}// r1 holds the value of the index, r3 has the value of the address of the output register
                            // they need to be preserved
                bl BIORead
                pop {r1, r3}
                // check whether the 'q' is recieved to terminate the wave gen
                cmp r0, #'q'
                bne qloop
                // turn off the wave gen
                mov r0, #0
                str r0,[r3]
                pop {r4,r5}
                pop {pc}
///////////////////////////////////////////////////////////
/**************************************************************************
* void InitializeIO(void) – This subroutine configure the portC to GPIO
* It also turns on the clock for the port and define the direction for the
* port
*
* Params: none
* Returns: none
* MCU: K22F
* Shao-Peng Yang, 02/12/2019
**************************************************************************/
InitializeIO:
                push {lr}
                //Initialize the Clock for GPIOC
                ldr r0, =#SIM_SCGC5
                ldr r1, [r0]
                orr r1, BIT0<<11
                str r1, [r0]
                //Mux the PORTC Bit 0 to GPIO
                ldr r0, =#PORTC_PCR0
                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8
                str r1, [r0], #8 // increment the pointer after
                                 // which change the pointer to the address for BIT2 (offset 8)

                // configure PORTC from bit 2 to 9
                // mux them to GPIO and enable the pull up resister
                // r0 stores the base address, it will increment by 4 everytime after configuration to point to next bit
                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0], #4

                ldr r1, [r0]
                and r1, #MUX_MASK_NEG
                orr r1, BIT0<<8 |BIT0|BIT0<<1
                str r1, [r0]
                // configure the direction for PORTC
                // it is reset to zero, so we just need to configure the direction for the output(bit 0)
                ldr r0, =GPIOC_PDDR
                ldr r1, [r0]
                orr r1, BIT0
                str r1, [r0]

                pop {pc}
                .section .rodata
Message:        .asciz "Please enter an integer from 1 to 16"
NewLine:        .asciz "\n\r"
Error:          .asciz "That is absolutely wrong\n\r"

                .section .bss
                .comm StgIN, 2 // array for the string entered from the terminal
                .comm CurrentSW, 1 // store the current state of the switch
/*****************************************************************************/
