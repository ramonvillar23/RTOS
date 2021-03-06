;/*****************************************************************************/
; OS.s: low-level OS commands, written in assembly                       */
; Runs on LM4F120/TM4C123
; OS functions.
; Ramon Villar, Kapil
; February, 9, 2016


        AREA |.text|, CODE, READONLY, ALIGN=2
        THUMB
        REQUIRE8
        PRESERVE8

        EXTERN  RunPt            ; currently running thread
		EXTERN  PF3Address
		EXTERN  traverseSleep
		EXTERN  switched
		EXTERN  nextBeforeSwitch	
		EXTERN  higherPriorityAdded
		EXTERN  SchedulerPt
		EXTERN  OS_MsTime
		EXTERN 	timeWithInterruptsDisabled
		EXTERN	startTimeOfInterruptsDisabled
		EXTERN  endTimeOfInterruptsDisabled
        EXPORT  OS_DisableInterrupts
        EXPORT  OS_EnableInterrupts
        EXPORT  PendSV_Handler
		EXPORT  SysTick_Handler
		EXPORT  StartOS
		EXPORT OS_StartCritical
		EXPORT OS_EndCritical
			
			


;*********** StartCritical ************************
; make a copy of previous I bit, disable interrupts
; inputs:  none
; outputs: previous I bit
OS_StartCritical
        MRS    R0, PRIMASK  ; save old status
        CPSID  I            ; mask all (except faults)
		PUSH{LR, R0} ;save R0 since it contains old status
		BL OS_MsTime
		LDR R1, =startTimeOfInterruptsDisabled
		STR R0, [R1]
		POP{LR, R0} ;restore status
        BX     LR

;*********** EndCritical ************************
; using the copy of previous I bit, restore I bit to previous value
; inputs:  previous I bit
; outputs: none
OS_EndCritical
        MSR    PRIMASK, R0
		LDR R2, =startTimeOfInterruptsDisabled
		LDR R2, [R2] ;R2 has start time
		PUSH{LR, R2}
		BL OS_MsTime ;R0 gets end time
		POP{LR, R2}
		SUB R0, R2, R0 ;R0 now has the time diff
		LDR R1, =timeWithInterruptsDisabled
		LDR R2, [R1]
		ADD R2, R0, R2
		STR R2, [R1]
        BX     LR


OS_DisableInterrupts
        CPSID   I
		PUSH{LR}
		BL OS_MsTime
		POP{LR}
		LDR R1, =startTimeOfInterruptsDisabled
		STR R0, [R1]
        BX      LR


OS_EnableInterrupts
		LDR R2, =startTimeOfInterruptsDisabled
		LDR R2, [R2] ;R2 has start time
		PUSH{LR, R2}
		BL OS_MsTime ;R0 gets end time
		POP{LR, R2}
		SUB R0, R2, R0 ;R0 now has the time diff
		LDR R1, =timeWithInterruptsDisabled
		LDR R2, [R1]
		ADD R2, R0, R2
		STR R2, [R1]
        CPSIE   I
        BX      LR

StartOS
	LDR R0, =RunPt
	LDR R2, [R0]
	LDR SP, [R2] ;load localSP
	POP {R4-R11}
	POP {R0-R3}
	POP {R12}
	POP {LR} ;trash LR
	POP {LR} ;PC on stack. the only register that is not trash. points to function that we want to run
	POP {R1} ;discards last one PSR
	CPSIE I 
	BX LR    ;LR contains the PC we want to return to
	


PendSV_Handler                ; 1) Saves R0-R3,R12,LR,PC,PSR
	CPSID I
	PUSH{R4-R11} ;push remaining registers
	LDR R0, =RunPt ;old run pointer
	LDR R1, [R0] ;now R1 points the the current TCB running
				 ;this means R1 = TCB.localSP 	
	STR SP, [R1] ;store stack into local stack pointer of TCB
	;need to check if we went to sleep or killed 
	LDR R2, =switched ;8bit variable
	LDRB R3, [R2] ;loadvalue of flag
	CMP R3, #0
	BNE Switch_Routine
	LDR R2, =higherPriorityAdded
	LDRB R3, [R2] ;load value of flag... if 1, a higher priority was added and need to update runpt to beginning of list
	CMP R3, #0
	BNE Higher_Priority_Switch
	BEQ Normal_Context_Switch
Higher_Priority_Switch
	MOV R3,#0 ;constant to clear the flag
	STRB R3,[R2] ;clear the flag, flag was 1
	LDR R1, =SchedulerPt
	LDR R1, [R1] ;R1 now points to higher priority thread
	STR R1, [R0] ;update runPt
	LDR SP, [R1] ;localSp to SP
	B END_ROUTINE
Switch_Routine ;used for kill and sleep
	MOV R3,#0
	STRB R3, [R2] ;clear the flag
	LDR R1, =nextBeforeSwitch
	LDR R1, [R1] ;now points to tcb that we want to run
	STR R1, [R0] ;update runPT
	LDR SP, [R1]
	B END_ROUTINE
Normal_Context_Switch	
	LDR R1, [R1,#4] ;load nextpt
	STR R1, [R0] ;update RunPt
	LDR SP, [R1] ;R1 points to the first element of the struct we want to switch to
END_ROUTINE
	POP {R4-R11} ;pop remainining registers
	CPSIE I
	BX LR
	
	
SysTick_Handler                ; 1) Saves R0-R3,R12,LR,PC,PSR
	CPSID I
	;PUSH{R4-R11} ;push remaining registers
	;LDR R0, =RunPt ;old run pointer
	;LDR R1, [R0] ;now R1 points the the current TCB running
				 ;this means R1 = TCB.localSP 	
	;STR SP, [R1] ;store stack into local stack pointer of TCB
	;added
	PUSH{R0-R1, LR}
	BL 	traverseSleep
	POP{R0-R1, LR}
	;added
	;LDR R1, [R1,#4] ;load nextpt
	;STR R1, [R0] ;update RunPt
	;LDR SP, [R1] ;R1 points to the first element of the struct we want to switch to
	;POP {R4-R11} ;pop remainining registers
	CPSIE I
	BX LR


    ALIGN
    END
