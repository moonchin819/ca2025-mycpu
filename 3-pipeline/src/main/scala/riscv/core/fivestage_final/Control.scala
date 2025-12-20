// SPDX-License-Identifier: MIT
// MyCPU is freely redistributable under the MIT License. See the file
// "LICENSE" for information on usage and redistribution of this file.

package riscv.core.fivestage_final

import chisel3._
import riscv.Parameters

/**
 * Advanced Hazard Detection and Control Unit: Maximum optimization
 *
 * Most sophisticated hazard detection supporting early branch resolution
 * in ID stage with comprehensive forwarding support. Achieves best
 * performance through aggressive optimization.
 *
 * Key Enhancements:
 * - **Early branch resolution**: Branches resolved in ID stage (not EX)
 * - **ID-stage forwarding**: Enables immediate branch operand comparison
 * - **Complex hazard detection**: Handles jump dependencies and multi-stage loads
 *
 * Hazard Types and Resolution:
 * 1. **Control Hazards**:
 *    - Branch taken in ID → flush only IF stage (1 cycle penalty)
 *    - Jump in ID → may need stall if operands not ready
 *
 * 2. **Data Hazards**:
 *    - Load-use for ALU → 1 cycle stall
 *    - Load-use for branch → 1-2 cycle stall depending on stage
 *    - Jump register dependencies → stall until operands ready
 *
 * Complex Scenarios Handled:
 *
 * Scenario 1 - Jump with load dependency:
 * ```
 * LW   x1, 0(x2)   # Load x1
 * JALR x3, x1, 0   # Jump to address in x1 → needs stall
 * ```
 *
 * Scenario 2 - Branch with recent ALU result:
 * ```
 * ADD x1, x2, x3   # Compute x1
 * BEQ x1, x4, label # Branch using x1 → forwarded to ID, no stall
 * ```
 *
 * Performance Impact:
 * - CPI ~1.05-1.2 (best achievable)
 * - Branch penalty reduced to 1 cycle
 * - Minimal stalls through aggressive forwarding
 *
 * @note Most complex control logic but best performance
 * @note Requires ID-stage forwarding paths for full benefit
 */
class Control extends Module {
  val io = IO(new Bundle {
    val jump_flag              = Input(Bool())                                     // id.io.if_jump_flag
    val jump_instruction_id    = Input(Bool())                                     // id.io.ctrl_jump_instruction           //
    val rs1_id                 = Input(UInt(Parameters.PhysicalRegisterAddrWidth)) // id.io.regs_reg1_read_address
    val rs2_id                 = Input(UInt(Parameters.PhysicalRegisterAddrWidth)) // id.io.regs_reg2_read_address
    val memory_read_enable_ex  = Input(Bool())                                     // id2ex.io.output_memory_read_enable
    val rd_ex                  = Input(UInt(Parameters.PhysicalRegisterAddrWidth)) // id2ex.io.output_regs_write_address
    val memory_read_enable_mem = Input(Bool())                                     // ex2mem.io.output_memory_read_enable   //
    val rd_mem                 = Input(UInt(Parameters.PhysicalRegisterAddrWidth)) // ex2mem.io.output_regs_write_address   //

    val if_flush = Output(Bool())
    val id_flush = Output(Bool())
    val pc_stall = Output(Bool())
    val if_stall = Output(Bool())
  })

  // Initialize control signals to default (no stall/flush) state
  io.if_flush := false.B
  io.id_flush := false.B
  io.pc_stall := false.B
  io.if_stall := false.B

  // ============================================================
  // [CA25: Exercise 19] Pipeline Hazard Detection
  // ============================================================
  // Hint: Detect data and control hazards, decide when to insert bubbles
  // or flush the pipeline
  //
  // Hazard types:
  // 1. Load-use hazard: Load result used immediately by next instruction
  // 2. Jump-related hazard: Jump instruction needs register value not ready
  // Ex. lw x2, 0(x3)
  //     jalr x1, x2, 0
  // The data of load word is read at MEM stage, and the address is calculate at EX stage
  // But JALR want to use x2 to calculate PC value at ID stage

  // 3. Control hazard: Branch/jump instruction changes PC

  //
  // Control signals:
  // - pc_stall: Freeze PC (don't fetch next instruction)
  // - if_stall: Freeze IF/ID register (hold current fetch result)
  // - id_flush: Flush ID/EX register (insert NOP bubble)
  // - if_flush: Flush IF/ID register (discard wrong-path instruction)

  // Complex hazard detection for early branch resolution in ID stage
  when(
    // ============ Complex Hazard Detection Logic ============
    // This condition detects multiple hazard scenarios requiring stalls:

    // --- Condition 1: EX stage hazards (1-cycle dependencies) ---
    // TODO: Complete hazard detection conditions
    // Need to detect:
    // 1. Jump instruction in ID stage
    // 2. OR Load instruction in EX stage
    // 3. AND destination register is not x0
    // 4. AND destination register conflicts with ID source registers
    //
    ((io.jump_instruction_id || io.memory_read_enable_ex) && // Either:
      // - Jump in ID needs register value, OR
      // - Load in EX (load-use hazard)
      io.rd_ex =/= 0.U &&                                 // Destination is not x0
      (io.rd_ex === io.rs1_id || io.rd_ex === io.rs2_id)) // Destination matches ID source
    //
    // Examples triggering Condition 1:
    // a) Jump dependency: ADD x1, x2, x3 [EX]; JALR x0, x1, 0 [ID] → stall
    // b) Load-use: LW x1, 0(x2) [EX]; ADD x3, x1, x4 [ID] → stall
    // c) Load-branch: LW x1, 0(x2) [EX]; BEQ x1, x4, label [ID] → stall

      || // OR

        // --- Condition 2: MEM stage load with jump dependency (2-cycle) ---
        // TODO: Complete MEM stage hazard detection
        // Need to detect:
        // 1. Jump instruction in ID stage
        // 2. Load instruction in MEM stage
        // 3. Destination register is not x0
        // 4. Destination register conflicts with ID source registers
        //
        (io.jump_instruction_id &&                              // Jump instruction in ID
          io.memory_read_enable_mem &&                          // Load instruction in MEM
          io.rd_mem =/= 0.U &&                                  // Load destination not x0
          (io.rd_mem === io.rs1_id || io.rd_mem === io.rs2_id)) // Load dest matches jump source
        //
        // Example triggering Condition 2:
        // LW x1, 0(x2) [MEM]; NOP [EX]; JALR x0, x1, 0 [ID]
        // Even with forwarding, load result needs extra cycle to reach ID stage
  ) {
    // Stall action: Insert bubble and freeze pipeline
    // TODO: Which control signals need to be set to insert a bubble?
    // Hint:
    // - Flush ID/EX register (insert bubble)
    // - Freeze PC (don't fetch next instruction)
    // - Freeze IF/ID (hold current fetch result)
    io.id_flush := true.B
    io.pc_stall := true.B
    io.if_stall := true.B

  }.elsewhen(io.jump_flag) {
    // ============ Control Hazard (Branch Taken) ============
    // Branch resolved in ID stage - only 1 cycle penalty
    // Only flush IF stage (not ID) since branch resolved early
    // TODO: Which stage needs to be flushed when branch is taken?
    // Hint: Branch resolved in ID stage, discard wrong-path instruction
    io.if_flush := true.B
    // Note: No ID flush needed - branch already resolved in ID!
    // This is the key optimization: 1-cycle branch penalty vs 2-cycle
  }

  // ============================================================
  // [CA25: Exercise 21] Hazard Detection Summary and Analysis
  // ============================================================
  // Conceptual Exercise: Answer the following questions based on the hazard
  // detection logic implemented above
  //
  // Q1: Why do we need to stall for load-use hazards?
  // A: Because a LOAD instruction only produces its data at the end of MEM stage.
  //    But the following instruction needs that data at the beginning of its EX stage. 
  //    So we need a one cycle stall to allow LOAD instruction to finish its memory access.
  // Hint: Consider data dependency and forwarding limitations
  //
  // Q2: What is the difference between "stall" and "flush" operations?
  
  // A: Stall operation freezes the pipeline registers such as PC and IF/ID, 
  //    forcing that instruction to stay in their current stage for an extra cycle, 
  //    effectively creates a delay.
  //    Flush operation clears the content of a pipeline register, typically by
  //    replacing the current instruction with a NOP or zeroing out control signals.
  //    This ensures that an incorrectly fetched or dependent instruction is not executed.
  // Hint: Compare their effects on pipeline registers and PC
  //
  // Q3: Why does jump instruction with register dependency need stall?
  // A: In this design, the jump target address is calculated early in the ID stage to reduce
  //    branch penalty. If the jump depends on a register being written by a previous instruction,
  //    that data might only be available in the EX or MEM stage. Since data cannot be forwarded
  //    backward in time within the same cycle from EX to ID, a stall is necessary to let the producer
  //    instruction move further down the pipeline until its result can be forwarded to the ID stage.
  // Hint: When is jump target address available?
  //
  // Q4: In this design, why is branch penalty only 1 cycle instead of 2?
  // A: The branch penalty depends on which stage the branch decision is resolved.
  //    In traditional designs, branches are resolved in EX stage, meaning two subsequent
  //    instructions have already been fetched and must be flushed if the branch is taken.
  //    But in this design, we moved the branch resolution to ID stage. When a branch is taken,
  //    only the single instruction currently in the IF stage is incorrect and needs to be flushed.
  //    Therefore, the penalty is reduced to 1 cycle.
  // Hint: Compare ID-stage vs EX-stage branch resolution
  //
  // Q5: What would happen if we removed the hazard detection logic entirely?
  // A: The CPU would suffer data inconsistency and incorrect control flow.
  //    First, if we can't detect data hazards, the CPU would execute instructions using old
  //    data from the register file before the previous instructions have finished updating them
  //    Second, being not able to detect control hazards, CPU would continue to execute instructions
  //    from the wrong path because it wouldn't know to flush the fetched instructions.
  //    Then the program would ultimately produce wrong results or crash.
  // Hint: Consider data hazards and control flow correctness
  //
  // Q6: Complete the stall condition summary:
  // Stall is needed when:
  // 1. Load-use hazard : When the instruciton
  //    in EX is a load and its destination register
  //    matches the source registers  of the instruction in ID. (EX stage condition)
  // 2. Jump/Branch data hazard : When the instruction in ID is a jump/branch
  //    and it depends on a register vlue being produced by a previous instruction
  //    currently in the EX or MEM stage.(MEM stage condition)
  //
  // Flush is needed when:
  // 1. Control hazard : When a branch or jump instruciton in the ID stage is 
  //    confirmed to be taken. We must flush the instruction in the IF stage
  //    to prevent executing the wrong-path instruction. (Branch/Jump condition)
  // 
}
