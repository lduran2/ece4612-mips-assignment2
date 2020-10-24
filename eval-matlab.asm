# eval-matlab.asm
# This program evaluates a Matlab expression.
#
# created by:	Leomar Duran <https://github.com/lduran2>
#            	Yacouba Bamba
#            	Moussa Fofana 
#            	Tairou Ouro-Bawinay
#       date:	2020-10-24 t19:36Z
#        for:	ECE 4612
#            	MIPS_Assignment2
#    version:	v2.2
######################################################################
# 3-check-matlab.asm
# This program validates a Matlab expression.
#
# created by:	Leomar Duran <https://github.com/lduran2>
#            	Yacouba Bamba
#            	Moussa Fofana 
#            	Tairou Ouro-Bawinay
#       date:	2020-10-24 t14:51Z
#        for:	ECE 4612
#            	MIPS_Assignment1
#    version:	v1.5
######################################################################
#
# ChangeLog
######################################################################
# 	v2.2 - 2020-10-24 t19:36Z
# 		Parsed operators.
#
# 	v2.1 - 2020-10-24 t17:37Z
# 		Parsed numbers.
#
# 	v2.0 - 2020-10-24 t14:51Z
# 		Limited to 4 operators, 4 digit operands.
#
# 	v1.5 - 2020-10-24 t13:07Z
# 		Implemented the error from digraph using flags.
#
# 	(v1.4) - 2020-09-30 t07:44Z
# 		Implemented the error from digraph ends using linking.
#
# 	v1.3 - 2020-09-30 t03:34Z
# 		Implemented the "no operators since" flags.
#
# 	v1.2 - 2020-09-30 t02:37Z
# 		Implemented even parentheses cheaker.
#
# 	v1.0 - 2020-09-29 t23:21Z
# 		Implemented character validator.
#
#	Versions in parentheses are defunct.
######################################################################

# command constants
.eqv	intprint   	1	# command to print integer $a0
.eqv	print   	4	# command to print $a0..NULL to the console
.eqv	strinput	8	# command to input $a1 characters into buffer $a0
.eqv	chrprint	11	# command to print character &a0
# number constants
.eqv	lastchar	63	# index of last character in strinput
# flag masks
.eqv	flParError	64	# flags uneven parentheses
.eqv	flOpndOptr	1	# flags no operator since operand
.eqv	flClPrOptr	2	# flags no operator since closed parenthesis
.eqv	flDgSt    	1	# flags digraph start
# maximums
.eqv	maxOptrsP1	5	# maximum number of operators + 1
.eqv	maxDigitsP1	5	# maximum number of digits per operand + 1

# evaluation constants
# flags
.eqv	inOperand	1	# evaluation inside an operand
.eqv	inOperator	2	# evaluation inside an operator
.eqv	outputBufOptr	16384	# marks an output buffer element as an operator

.text	# the code block

# Accept a uster string and save it.
inpChk:
	# $s0 := address of input buffer
	# $s1 := error character number
	#
	# display the prompt
	la	$a0, matPrompt           	# load the address of prompt buffer (null terminated)
	addi	$v0, $zero, print        	# print command
	syscall	# print the prompt
inpChkInput:
	# get the input from the console
	la	$a0, inpStr              	# load the address of input buffer
	la	$a1, inpStr              	# load the  length of input buffer
	addi	$v0, $zero, strinput     	# string input command
	syscall	# accept the matlab expression
	la	$s0, inpStr              	# store the address of the input buffer
inpChkValidate:
	# validate the string
	or	$a0, $zero, $s0          	# copy address into argument $a0
	jal	matchk                   	# call matchk
	beq	$v0, $zero, inpChkInvalid	# if (valid string) else go to print the invalid message
	or	$a0, $zero, $s0          	# copy address into argument $a0
	jal	mateva                   	# call mateva
	j	inpChkOutput             	# finish the loop
inpChkInvalid:
	la	$a0, invMessage          	# load address of invalid message
	addi	$v0, $zero, print        	# print command
	syscall	# print the message
	#j inpChkOutput	# don't print the character index
inpChkIndex:	# used for debugging
	la	$a0, linePrompt          	# load address of line number prompt
	addi	$v0, $zero, print        	# print command
	syscall	# print the message
	la	$a1, invMessage          	# load  length of invalid message
	or	$s1, $zero, $v1          	#  copy the error information
	andi	$a0, $s1, lastchar       	#  copy line number to print
	addi	$v0, $zero, intprint     	# print line number
	syscall	# print the line number
	j	inpChkOutput             	# finish the loop
inpChkOutput:
	addi	$a0, $zero, '\n'         	#  load newline
	addi	$v0, $zero, chrprint     	# print newline
	syscall	# print newline
	j	inpChk                   	# repeat the program
# end inpChk


######################################################################
# Evaluates a Matlab expression.
#
mateva:
	# $t0 := index, k
	# $t1 := address, (X + k)
	# $t2 := character, X[k]
	# $t4 := flags
	# $t5 := operand
	# $t6 := output buffer pointer
	# $t7 := initial stack pointer
	# $t8 := arithmetic temp #0
	# $t9 := arithmetic temp #1
	and	$t4, $zero, $zero	# clear flags
	la	$t6, outputBuf		# load the address of the output buffer
	or	$t7, $t7, $sp		# copy the stack pointer
	or	$t0, $zero, $zero	# for k = 0,
matEvaL1: # matlab evaluation loop 1
	add	$t1, $t0, $a1		# find X + k
	lb	$t2, 0($t1)		# get X[k] alias *(X + k)
	beq	$t2, $zero, matEvaDone	# if (end of string), then done
	ori	$t8, $zero, '\n'	# load newline
	beq	$t2, $t8, matEvaDone	# if (X[k] == newline), then done
matEvaChkTkOpnd:
	# if token is an operand
	sltiu	$t8, $t2, '0'			# if (X[k] < '0')
	bne	$t8, $zero, matEvaTkNOpnd	#   not an operand;
	sltiu	$t8, $t2, ':'			# if (X[k] <= '9')
	bne	$t8, $zero, matEvaTkYOpnd	#   operand;
	j	matEvaTkNOpnd			# not an operand;

matEvaTkYOpnd:
	andi	$t8, $t4, inOperand	# if (inOperand)
	beq	$t8, $zero, matEvaTkYOpndNiOpnd
matEvaTkYOpndYiOpnd: # token is an operand, and in an operand
	or	$t8, $zero, $t5		# copy the operand so far
	sll	$t9, $t8, 2		# $t9 = $t8 * 4, 4 = 2^2
	add	$t8, $t8, $t9		# $t8 += $t9
	sll	$t8, $t8, 1		# $t8 *= 2, 2 = 2^1
	# the result is: $t8 = $t5 * 10;
	subi	$t9, $t2, '0'		# convert the new character to an integer
	add	$t5, $t8, $t9		# operand = (operand * 10) + (X[k] - '0')
	j matEvaNext	# continue next loop run
# otherwise
matEvaTkYOpndNiOpnd: # token is an operand, but not in an operand
	subi	$t5, $t2, '0'		# convert the new character to an integer
	or	$t4, $t4, inOperand	# set the inOperand flag
	j matEvaNext	# continue next loop run
matEvaTkNOpnd: # token is not an operand
	andi	$t8, $t4, inOperand	# if (inOperand)
	beq	$t8, $zero, matEvaTkNOpndNiOpnd
matEvaTkNOpndYiOpnd: # token is not an operand, but in an operand
	sw	$t5, 0($t6)		# store the last operand
	addi	$t6, $t6, 4		# next location in the output buffer
	# fall through
matEvaTkNOpndNiOpnd: # token is not an operand, and not in an operand
	ori	$t8, $zero, inOperand	# store inOperand mask
	nor	$t8, $t8, $t8		# invert
	and	$t4, $t4, $t8		# clear the mask
matEvaChkTkOptrP2: # check if an operator priority 2
	ori	$t8, $zero, '*'			# if ('*'
	beq	$t2, $t8, matEvaTkYOptrP2	#   == X[k]) operator;
	ori	$t8, $zero, '/'			# if ('/'
	beq	$t2, $t8, matEvaTkYOptrP2	#   == X[k]) operator;
matEvaChkTkOptrP1: # check if an operator priority 1
	ori	$t8, $zero, '+'			# if ('+'
	beq	$t2, $t8, matEvaTkYOptrP1	#   == X[k]) operator;
	ori	$t8, $zero, '-'			# if ('-'
	beq	$t2, $t8, matEvaTkYOptrP1	#   == X[k]) operator;
	j matEvaTkNOptr	# otherwise, it's not an operator
matEvaTkYOptrP2: # all operators are >= priority
matEvaTkYOptrP2L2: # stop if +/-
	beq	$sp, $t7, matEvaTkYOptrP1L2end	# exit the loop if stack is empty
	lw	$t5, 0($sp)		# pop an operator
	ori	$t8, $zero, '+'			# if ('+'
	beq	$t5, $t8, matEvaTkYOptrP1L2end	#   == X[k]) stop;
	ori	$t8, $zero, '-'			# if ('-'
	beq	$t5, $t8, matEvaTkYOptrP1L2end	#   == X[k]) stop;
	addi	$sp, $sp, 4		# move stack pointer
	ori	$t5, outputBufOptr	# flag as operator
	sw	$t5, 0($t6)		# store the next operator
	addi	$t6, $t6, 4		# next location in the output buffer
	j	matEvaTkYOptrP1L2	# next element in stack
matEvaTkYOptrP2L2end:
	j	matEvaTkYOptrP1L2end	# jump to after both loops
matEvaTkYOptrP1: # all operators are >= priority
matEvaTkYOptrP1L2:
	beq	$sp, $t7, matEvaTkYOptrP1L2end	# exit the loop if stack is empty
	lw	$t5, 0($sp)		# pop an operator
	addi	$sp, $sp, 4		# move stack pointer
	ori	$t5, outputBufOptr	# flag as operator
	sw	$t5, 0($t6)		# store the next operator
	addi	$t6, $t6, 4		# next location in the output buffer
	j	matEvaTkYOptrP1L2	# next element in stack
matEvaTkYOptrP1L2end:
	addi	$sp, $sp, -4	# move stack pointer to push an operator
	sw	$t2, 0($sp)	# push an operator
	j matEvaNext	# continue next loop run
matEvaTkNOptr: # token is not an operator
	j matEvaNext	# continue next loop run
matEvaNext:
	addi	$t0, $t0, 1            	# ++k
	j	matEvaL1               	# next k
matEvaDone:	# pop the rest of the tokens
	beq	$sp, $t7, rMatEva	# exit the loop if stack is empty
	lw	$t5, 0($sp)		# pop an operator
	addi	$sp, $sp, 4		# move stack pointer
	ori	$t5, outputBufOptr	# flag as operator
	sw	$t5, 0($t6)		# store the next operator
	addi	$t6, $t6, 4		# next location in the output buffer
	j	matEvaDone	# next element in stack
rMatEva:
	jr	$ra	# return to caller


######################################################################
# Validates a Matlab expression.
#
# The following rules are allowed:
#   expression is up to 64 characters
#   characters allowed [(-+\-/-9=]
#     only parentheses, digits from 0 to 9
#     operators +, -, *, /, and “=”.
#   no space between digits
#     no need because space is an invalid character
#   check for uneven parentheses
#   no operator between operand and open parenthesis
#   no operator between close parenthesis and operand
#   syntax errors:
#     (/
#     //
#     +/
#     -/
#     */
#     (*
#     /*
#     +*
#     -*
#     **
#     ()
#     /)
#     +)
#     -)
#     *)
#
# params:
#   $a0 := address of Matlab expressions
matchk: # matchk(char *X) : void
	# $t0 := index, k
	# $t1 := address, (X + k)
	# $t2 := character, X[k]
	# $t3 := boolean, if (X[k] < some character)
	# $t4 := character, temporary load
	# $t5 := counter, i_parentheses
	#                 of (open parentheses - close parentheses)
	# $t6 := flags for operator between
	# $t7 := flags for digraph start and end
	# $t8 := counter, i_operators of operators
	# $t9 := counter, i_digits of digits in operand
	#
	# flow:
	# 	[(] -> dgst -> val
	# 	[)] -> dgfn -> val
	# 	[/*] -> dgfn -> dgst -> optr -> val
	# 	[+-] -> dgst -> optr -> val
	# 	[=] -> optr -> val
	# 	[0-9] -> opnd -> val
	#
	# (dgst, dgfn) are flags, checked in val, rather than
	# intermediate routines
	#
	and	$v1, $zero, $zero      	# clear $v1
	and	$t6, $zero, $zero      	# clear operator between flags
	and	$t7, $zero, $zero      	# clear the digraph flags
	or	$t5, $zero, $zero      	# i_parentheses = 0
	or	$t8, $zero, $zero      	# i_operators = 0
	or	$t9, $zero, $zero      	# i_digits = 0
	or	$t0, $zero, $zero      	# for k = 0,
matChkL1:
	add	$t1, $t0, $a1          	# find X + k
	lb	$t2, 0($t1)            	# get X[k] alias *(X + k)
	beq	$t2, $zero, matChkValid	# if (end of string), then valid
	addi	$t4, $zero, '\n'       	# load newline
	beq	$t2, $t4, matChkValid	# if (X[k] == newline), then valid
	j	matChkCharRng          	# check if the character is in range
matChkChVal:	# character is valid
	# check whether maximums exceeded
	beq	$t8,  maxOptrsP1, matChkInval	# if (i_operators ==  maxOptrs + 1) then string is invalid;
	beq	$t9, maxDigitsP1, matChkInval	# if (   i_digits == maxDigits + 1) then string is invalid;
	addi	$t0, $t0, 1            	# ++k
	j	matChkL1               	# next k
matChkInval:	# string is not valid
	and	$v0, $zero, $zero      	# clear valid flag
	or	$v1, $v1, $t0          	# $v1 |= k
	j	rMatChk                	# finish
matChkValid:
	bne	$t5, $zero, matChkInval	# invalid if parentheses uneven
	addi	$v0, $zero, 1          	#   set valid flag
rMatChk:
	jr	$ra                    	# return to caller
# end matchk

######################################################################
# Matlab check: character ranges
#   characters allowed [(-+\-/-9=]
#    , after +, : after 9
matChkCharRng:
matChkCharR10:	# character range 10 [(-+]
	ori	$t4, $zero, '('        	# load '('
	beq	$t2, $t4, matChkOpPar  	# if (X[k] == '(')  open parenthesis;
	ori	$t4, $zero, ')'        	# load ')'
	beq	$t2, $t4, matChkClPar  	# if (X[k] == ')') close parenthesis;
	ori	$t4, $zero, '*'        	# load '*'
	beq	$t2, $t4, matChkSlAs   	# if (X[k] == '*') slash or asterisk;
	ori	$t4, $zero, '+'        	# load '+'
	beq	$t2, $t4, matChkPlMn   	# if (X[k] == '+') plus or minus;
matChkCharMns:	# character -
	ori	$t4, $zero, '-'        	# load '-'
	beq	$t2, $t4, matChkPlMn   	# if (X[k] == '-') plus or minus;
matChkCharR20:	# character round 20 [/-9]
	ori	$t4, $zero, '/'        	# load '/'
	beq	$t2, $t4, matChkSlAs   	# if (X[k] == '/') slash or asterisk;
	sltiu	$t3, $t2, '0'          	# if (X[k] < '0')
	bne	$t3, $zero, matChkInval	#   invalid string;
	sltiu	$t3, $t2, ':'          	# if (X[k] <= '9')
	bne	$t3, $zero, matChkOpnd 	#   operand;
matChkCharEqu:	# character =
	ori	$t4, $zero, '='        	# load '='
	# '=' used for assignment
	# beq	$t2, $t4, matChkEqls   	# if (X[k] == '=') equals;
matChkCharEl:	# matched none of the classes
	j	matChkInval            	# else invalid string;
#

######################################################################
# # Matlab check: parentheses
matChkOpPar:	# character is an open parenthesis
	andi	$t3, $t6, flOpndOptr   	# if (no operator since last operand)
	bne	$t3, $zero, matChkInval	#   invalid string;
	addi	$t5, $t5, 1            	# ++i_parentheses
	ori	$t7, $t7, flDgSt	# start digraph
	j	matChkChVal            	#  open parenthesis is valid
matChkClPar:	# character is a close parenthesis
	andi	$t3, $t6, flClPrOptr   	# if (no operator since last close parenthesis)
	bne	$t3, $zero, matChkInval	#   invalid string;
	andi	$t3, $t7, flDgSt	# if (in digraph)
	bne	$t3, $zero, matChkInval	#   invalid string;
	addi	$t5, $t5, -1           	# --i_parentheses
	ori	$t6, $t6, flClPrOptr   	# flag no operator since last closed parenthesis
	j	matChkChVal            	# close parenthesis is valid
#

######################################################################
# # Matlab check: character classes
matChkEqls:
	and	$t7, $zero, $zero   	# end diagraph
	# fall through into operator
matChkOptr:	# character is an operator
	add	$t6, $zero, $zero   	# clear both between flags
	addi	$t8, $t8, 1         	# ++i_operator
	j	matChkChVal	    	# operator is valid
matChkOpnd:	# character is an operand
	andi	$t3, $t6, flClPrOptr   	# if (no operator since last close parenthesis)
	bne	$t3, $zero, matChkInval	#   invalid string;
	# if an operand appears after another operand, they are the same operand.
	# so only an operator and/or parenthesis can appear between two operands.
	# an open parenthesis may not appear directly after an operand.
	# a close parenthesis may appear after an operand,
	#	but an operand may not appear after a close parenthesis.
	# therefore, there must always be an operator between two operands.
	# we can use this to check for the beginning of a new operand.
	andi	$t3, $t6, flOpndOptr   	# if (the flag no operator since last operand is true)
	bne	$t3, $zero, matChkCntOp	#   then we are continuing an operand.
	# otherwise, reset the count
	or	$t9, $zero $zero	# i_digits = 0
matChkCntOp:	# continuing an operand
	add	$t9, $t9, 1         	# ++i_digits
	ori	$t6, $t6, flOpndOptr	# flag no operator since last operand
	and	$t7, $zero, $zero   	# end diagraph
	j	matChkChVal	    	# operand is valid
matChkSlAs:	# character is slash or asterisk
	andi	$t3, $t7, flDgSt	# if (in digraph already)
	bne	$t3, $zero, matChkInval	#   invalid string;
	# otherwise, fall through into plus, minus
matChkPlMn:	# character is plus or minus
	ori	$t7, $t7, flDgSt	# start digraph
	j	matChkOptr	    	# plus, minus are operators
#

.data	#  the data block
 matPrompt:	.ascii ">>>\0"	# prompt for input
    inpStr:	.space 64	# the input buffer
invMessage:	.ascii "Invalid input\0\0\0"	# output for invalid input
valMessage:	.ascii "Valid input\0"      	# the input buffer
linePrompt:	.ascii " at: \0\0\0"      	# the prompt for line number
 outputBuf:	.space 64	# the output buffer
# end .data
