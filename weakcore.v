// SPDX-License-Identifier: MPL-2.0
/*
 * My first step on digital logic design: a small state-machine-based RV32I
 * core.
 *
 * Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

module weakcore(
	input wire clk, input wire rst,

	input wire [31:0] bus_in,
	output wire [31:0] bus_out,
	output wire [31:0] bus_addr,
	output wire bus_req,
	input wire bus_ack,
	output wire bus_wr);

	/* ==================== Register Heap ==================== */

	reg [31:0] regs [0:31];

	always @ (posedge clk) begin
		if (~rst)
			regs[0] <= 32'h0;
	end

	reg [3:0] stage_state;
	wire stage_if = stage_state[0];
	wire stage_exe = stage_state[2];
	wire stage_wb = stage_state[3];
	wire ready_if;
	wire [3:0] stage_ready = { 3'b111, ready_if };

	always @ (posedge clk) begin
		if (~rst)
			stage_state <= 4'b0001;
		else if (|(stage_ready & stage_state))
			stage_state <= { stage_state[2:0], stage_state[3] };
	end

	/* ================= Instruction fetch ======================== */
	reg [31:0] pc;
	reg [31:0] instr;
	always @ (posedge clk) begin
		if (~rst) begin
			pc <= 32'h0;
		end else if (stage_if & bus_ack) begin
			pc <= pc + 32'd4;
			instr <= bus_in;
		end
	end

	assign ready_if	= bus_ack;

	assign bus_req	= stage_if;
	assign bus_addr	= pc;
	assign bus_wr	= 1'b0;

	/* ===================== Decode =============================== */
	/* RISC-V instruction formats */
	wire [6:0] instr_opcode = instr[6:0];
	wire [2:0] instr_func3 = instr[14:12];
	wire [6:0] instr_func7 = instr[31:25];

	wire is_cond_branch     = instr_opcode == 7'b1100011;
	wire is_load            = instr_opcode == 7'b0000011;
	wire is_store           = instr_opcode == 7'b0100011;
	wire is_imm_arith       = instr_opcode == 7'b0010011;
	wire is_reg_arith       = instr_opcode == 7'b0110011;

	wire is_addi    = is_imm_arith && instr_func3 == 3'b000;
	wire is_add     = is_reg_arith && instr_func3 == 3'b000;
	wire is_lw      = is_load && instr_func3 == 3'b010;
	wire is_sw      = is_store && instr_func3 == 3'b010;

	wire [4:0] instr_rd     = instr[11:7];
	wire [4:0] instr_rs1    = instr[19:15];
	wire [4:0] instr_rs2    = instr[24:20];

	wire [31:0] instr_i_imm = {{20{instr[31]}}, instr[31:20]};
	wire [31:0] instr_s_imm = {{20{instr[31]}}, instr[31:25], instr_rd};
	wire [31:0] instr_b_imm =
		{{19{instr[31]}},
		 instr[31], instr[7], instr[30:25], instr[11:8],
		 1'b0 };
	wire [31:0] instr_u_imm = {instr[31:12], 12'b0};
	wire [31:0] instr_j_imm =
		{{11{instr[31]}},
		 instr[31], instr[19:12], instr[20], instr[30:21],
		 1'b0};

	// 2 source registers, 0 immediate
	wire is_r_type = is_add;
	// 1 source registers, 1 immediate, no destination, 1 address register
	wire is_s_type = is_sw;
	wire is_b_type;
	// 1 source register, 1 immediate
	wire is_i_type = is_addi | is_lw;
	// 0 source register, 1 immediate
	wire is_u_type;
	wire is_j_type;

	wire is_reg_arg1 = is_r_type | is_s_type | is_b_type | is_i_type;
	wire is_reg_arg2 = is_r_type | is_s_type | is_b_type;
	wire is_with_imm = is_s_type | is_b_type | is_i_type |
			   is_u_type | is_j_type;

	wire [31:0] instr_imm = ({32{is_s_type}} & instr_s_imm) |
				({32{is_b_type}} & instr_b_imm) |
				({32{is_i_type}} & instr_i_imm) |
				({32{is_u_type}} & instr_u_imm) |
				({32{is_j_type}} & instr_j_imm);

	/* How to execute the operation */
	wire op_add = is_add | is_addi;
	wire op_load;
	wire op_store;

	wire [31:0] op_arg1 = {32{is_reg_arg1}} & regs[instr_rs1];
	wire [31:0] op_arg2 = ({32{is_reg_arg2}} & regs[instr_rs2]) |
			      ({32{is_with_imm}} & instr_imm);

	/* How to process the result in writeback stage */
	wire op_wb = is_addi | is_add | is_load;
	wire op_jump;

	/* =========================== Execution ====================== */
	reg [31:0] op_result;

	wire [31:0] op_tmp_result =
		{32{op_add}} & (op_arg1 + op_arg2);

	always @ (posedge clk) begin
		if (~rst)
			op_result <= 32'h0;
		else if (stage_exe)
			op_result <= op_tmp_result;
	end

	/* ========================== Write back ====================== */
	always @ (posedge clk) begin
		if (stage_state[3] & op_wb & (|instr_rd)) begin
			regs[instr_rd] <= op_result;
		end
	end

`ifdef DUMP
	initial begin
		$dumpfile("dump.vcd");
		$dumpvars();
	end
`endif
endmodule;
