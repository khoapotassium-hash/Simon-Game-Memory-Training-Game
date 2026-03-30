# --- SUBJECT 2 - EXERCISE 13: SIMON GAME ---
# Group 10:- 202417144 Dang Viet Khoa
#          - 202417209 Tran Quang Trung

# Using Bitmap Display: Unit 8x8, Display 256x256, Base Heap (0x10040000);
# and Keyboard and Display MMIO Simulator


.eqv BASE_HEAP 0x10040000 # Bitmap Display Base Address

# --- COLOR ---
.eqv RED_OFF	0x00550000
.eqv RED_ON	0x00FF0000
.eqv GREEN_OFF	0x00005500
.eqv GREEN_ON	0x0000FF00
.eqv BLUE_OFF	0x00000055
.eqv BLUE_ON	0x000000FF
.eqv YELLOW_OFF	0x00555500
.eqv YELLOW_ON	0x00FFFF00
.eqv BLACK	0x00000000

.data
array:		.space 400
intro:		.string "--- GAME STARTED! ---"
level:		.string "\n\nLevel: "
choice_notice:	.string "\nChoose (1,2,3,4)"
answer:		.string "\n[Your answer]: "
lose:		.string "\n--- GAME OVER! ---"

.text
.globl main

main:
	# --- GAME SETUP ---
li s0, 0 			# Start level = 0

li a0, 0
li a1, 0
li a2, 0
li a3, 0
li a7, 31
ecall
li a0, 500
jal delay

# Print intro
li a7, 4
la a0, intro
ecall

# Reset screen visuals and draw 4 color-off blocks
jal clear_screen
jal draw_all_off

# Delay 1.5s and start game
li a0, 1500
jal delay


	# --- MAIN GAME PHASES ---
main_game_loop:
addi s0, s0, 1 			# level++

# Print level
li a7, 4
la a0, level
ecall
li a7, 1
mv a0, s0
ecall

#Delay 0.5s and go to the next level
li a0, 500
jal delay

# 1. MACHINE CREATE RANDOM NUMBER AND DISPLAY COLOR BLOCK
jal machine_turn


# 2. USER INPUT
li a7, 4
la a0, choice_notice
ecall
jal check_user_input

j main_game_loop


	# --- GAME LOGIC ---
# 1. MACHINE CREATE RANDOM NUMBER AND DISPLAY COLOR
machine_turn:
addi sp, sp, -4
sw ra, 0(sp)

# Syscall 42: Random int in range [0, a1 - 1]
li a7, 42
li a1, 4				# Range [0,3]
ecall
addi t0, a0, 1			# Plus 1 for converting to [1,4]

# Store new int into array
la t1, array
addi t2, s0, -1			# Current index = current level - 1
add t1, t1, t2
sb t0, 0(t1)

# Display color
jal machine_run_array

lw ra, 0(sp)
addi sp, sp, 4
ret

machine_run_array:
addi sp, sp, -12
sw ra, 0(sp)
sw s2, 4(sp)
sw s3, 8(sp)

mv s3, s0			# n = current level
li s2, 0				# i = 0
playback_loop:
bge s2, s3, playback_end		# while (i < n)

# Load color code
la t5, array
add t6, t5, s2
lb a0, 0(t6)

jal flash_beep

addi s2, s2, 1			# i++
j playback_loop

playback_end:
lw s3, 8(sp)
lw s2, 4(sp)
lw ra, 0(sp)
addi sp, sp, 12
ret


# 2. CHECK USER'S INPUT
check_user_input:
addi sp, sp, -16
sw ra, 0(sp)
sw s2, 4(sp)
sw s3, 8(sp)
sw s4, 12(sp)

li a7, 4
la a0, answer
ecall

mv s3, s0			# n = current level
li s4, 0 			# i = 0

check_loop:
bge s4, s3, PASS			# while (i < n). If all inputs are correct, PASS 
				# -> Return USER INPUT, move to next level.
			
jal polling
mv t1, a0			# check t1
la t5, array
add t6, t5, s4
lb t2, 0(t6)			# t2 is current number

bne t1, t2, game_over

mv a0, t1
jal flash_beep

addi s4, s4, 1 			# i++
j check_loop

PASS:
lw s4, 12(sp)
lw s3, 8(sp)
lw s2, 4(sp)
lw ra, 0(sp)
addi sp, sp, 16
ret


	# --- GAME OVER ---
game_over:
li a7, 4
la a0, lose
ecall
li a7, 10
ecall


	# --- Polling ---
polling:
li t3, 0xffff0000
li t4, 0xffff0004

loop_polling:
li a7, 32
li a0, 20
ecall

# Check flag
lw t1, 0(t3)
andi t1, t1, 1
beqz t1, loop_polling		# flag = 0, no key is pressed, continue waiting

lw a0, 0(t4)			# flag = 1, read data

# Print the user's input
addi sp, sp, -4
sw a0, 0(sp)

lw t6, 0(sp)
li a7, 1
addi a0, t6, -48
ecall

lw a0, 0(sp)
addi sp, sp, 4

addi a0, a0, -48			# convert ASCII of 1 = 49 -> number 1

# Only take the value in [1,4]
li t1, 1
blt a0, t1, loop_polling
li t1, 4
bgt a0, t1, loop_polling

ret


	# --- EFFECTS ---
# 1. Flash and Beep 
flash_beep:
addi sp, sp, -8
sw ra, 0(sp)
sw s5, 4(sp)
mv s5, a0

# Turn on 1 block corresponding to 1 number in array
# Flash
mv a0, s5
li a1, 1
jal draw_block

# Beep
li t0, 4
mul a0, s5, t0		
addi a0, a0, 52
# Syscall 31 playing sound
li a1, 800
li a2, 0
li a3, 100
li a7, 31
ecall

# Effect duration
li a0, 800
jal delay

# Off in 0.15s between 2 flash in row
mv a0, s5
li a1, 0
jal draw_block

li a0, 150
jal delay

flash_end:
lw s5, 4(sp)
lw ra, 0(sp)
addi sp, sp, 8
ret

# 2. Draw 4 color-off blocks at beggining 
draw_all_off:
addi sp, sp, -4
sw ra, 0(sp)

li a0, 1
li a1, 0
jal draw_block

li a0, 2
li a1, 0
jal draw_block

li a0, 3
li a1, 0
jal draw_block

li a0, 4
li a1, 0
jal draw_block

lw ra, 0(sp)
addi sp, sp, 4
ret


	# --- SUB-EFFECT ---
# 1. Draw a single block
draw_block:
li t1, 1
beq a0, t1, pick_1

li t1, 2
beq a0, t1, pick_2

li t1, 3
beq a0, t1, pick_3

li t1, 4
beq a0, t1, pick_4

ret

# (1 = ON; 0 = OFF)
pick_1:
beqz a1, red_off_mode
li a2, RED_ON
j coordinates
red_off_mode:
li a2, RED_OFF
j coordinates

pick_2:
beqz a1, green_off_mode
li a2, GREEN_ON
j coordinates
green_off_mode:
li a2, GREEN_OFF
j coordinates

pick_3:
beqz a1, blue_off_mode
li a2, BLUE_ON
j coordinates
blue_off_mode:
li a2, BLUE_OFF
j coordinates

pick_4:
beqz a1, yellow_off_mode
li a2, YELLOW_ON
j coordinates
yellow_off_mode:
li a2, YELLOW_OFF
j coordinates

coordinates:
# Display size: 256x256, unit size: 8x8 -> 32x32 units
# 4 blocks at 4 quadrants, each block size 14x14 units.
# Gaps used for visual separation.
# (x,y) = (a3,a4)
li t1, 1
beq a0, t1, block_1

li t1, 2
beq a0, t1, block_2

li t1, 3
beq a0, t1, block_3

block_4:
li a3, 16
li a4, 16
j draw_unit

block_1:
li a3, 1
li a4, 1
j draw_unit

block_2:
li a3, 16
li a4, 1
j draw_unit

block_3:
li a3, 1
li a4, 16
j draw_unit

draw_unit:
li t0, 14
mv t2, a4 # current y

draw_y:
li t1, 14
mv t3, a3 # current x

draw_x:
# Address: Heap Base + (Y * 32 + X) * 4 
# 1 unit = 1 word = 4 bytes
# units are stored in row-major order 
li t5, 32
mul t6, t2, t5
add t6, t6, t3
slli t6, t6, 2
li t5, BASE_HEAP
add t6, t5, t6

sw a2, 0(t6) # Draw

addi t3, t3, 1 # next x
addi t1, t1, -1
bnez t1, draw_x

addi t2, t2, 1 # next y
addi t0, t0, -1
bnez t0, draw_y
ret

# 2. Delay Function
delay:
mv a0, a0
li a7, 32
ecall
ret

# 3. Clear entire screen
clear_screen:
li t0, BASE_HEAP
li t1, 1024 # = 32x32 units
li t2, BLACK
cls_loop:
sw t2, 0(t0)
addi t0, t0, 4
addi t1, t1, -1
bnez t1, cls_loop
ret
